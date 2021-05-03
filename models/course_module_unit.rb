class CourseModuleUnit < ApplicationRecord
  belongs_to :course_module
  has_and_belongs_to_many :course_packages
  belongs_to :unit_content, polymorphic: true, autosave: true, dependent: :destroy
  has_many :results, foreign_key: 'unit_id', class_name: 'CourseModuleUnitResult', dependent: :destroy
  delegate :course, :to => :course_module

  has_enumeration_for :unit_type, with: CourseModuleUnitType, create_helpers: true, required: true

  attr_accessor :skip_unit_content_initialization

  before_validation :init
  after_destroy :recalculate_serial_numbers

  scope :published_units, -> (user, course_id = nil) {
    user_units(user, course_id)
        .where(published: true)
        .joins(:course_module).includes(:course_module).where(CourseModule.table_name => {published: true})
  }

  # Возвращает список моделей юнитов доступных пользователю.
  # @param user [User]: Модель пользователя.
  # @param params [Parameters|Hash]: Допонительные параметры для фильрации записей.
  #   - :course_id [Bigint] - Идентификатор курса, из которого нужно брать юниты.
  # @return [Array<CourseModuleUnit>]: Список моделей юнитов доступных пользователю.
  def self.allowed_units(user, params={})
    return if user.blank?
    published_units(user, params[:course_id])
  end

  # Возвращает список моделей юнитов-задач.
  # @param user [User]: Модель пользователя.
  # @param params [Parameters|Hash]: Допонительные параметры для фильрации записей.
  #   - :course_id [Bigint] - Идентификатор курса, из которого нужно брать юниты. Пусто - из всех курсов.
  #   - :states [Array<Integer>] - Список стутусов юнитов, по которым нужно отбирать юниты. Пусто - все статусы.
  #   - :order [String] - Сортировка по дате открытия модуля ('asc'/'desc'), по умолчанию по возрастанию.
  # @return [Array<CourseModuleUnit>]: Список моделей юнитов-заданий.
  def self.task_units(user, params={})
    return if user.blank?
    units = allowed_units(user, params)
    units = units.order(start_date: params[:order].downcase.to_sym) if params[:order]
    units = units.where(unit_type: CourseModuleUnitType::PRACTICE)
    return units if params[:states].blank?
    units.select { |unit| params[:states].include?(unit.state(user)) }
  end

  # Возвращает список моделей юнитов для расписания событий.
  # @param user [User]: Модель пользователя.
  # @param params [Parameters|Hash]: Допонительные параметры для фильрации записей.
  #   - :course_id [Bigint] - Идентификатор курса, из которого нужно брать юниты. Пусто - из всех курсов.
  #   - :start_date [String|Date] - С какой даты открытия нужно начать отбор юнитов. Пусто - текущая дата.
  #   - :deadline [Boolean] - Нужно ли смотреть, чтобы дата закрытия входила в диапазон, по умолчанию не смотрим.
  # @return [Array<CourseModuleUnit>]: Список моделей юнитов для расписания событий.
  def self.schedule(user, params={})
    return if user.blank?
    # Возьмем диапазон в 1 неделю
    start_date = params[:start_date].try(:to_date) || Date.current
    end_date = start_date + 1.week
    units = where(id: allowed_units(user, params).select(&:id))
    # Соберем отдельно юниты вебинаров по start_datetime
    webinar_units = units.where(unit_type: CourseModuleUnitType::WEBINAR)
                        .joins(sanitize_sql_for_assignment([%{
                               JOIN webinars ON course_module_units.unit_content_id = webinars.id AND
                               webinars.start_datetime BETWEEN :start_date AND :end_date
                               }, start_date: start_date, end_date: end_date + 1.days]))
                        .includes(:unit_content)
    # Исключим вебинары из последующих выборок
    units = units.where.not(unit_type: CourseModuleUnitType::WEBINAR).order(start_date: :asc)
    units = units.where(start_date: start_date..end_date).or(units.where(deadline: start_date..end_date))
    units = (webinar_units + units).sort_by do |obj|
      if obj.unit_type == CourseModuleUnitType::WEBINAR
        obj.unit_content.start_datetime || obj.start_date || obj.deadline
      else
        obj.start_date || obj.deadline
      end
    end
    return units if params[:deadline].blank?
    # Для deadline дополнительно проверим статус юнитов, вебинары отбираются всегда
    units.select do |unit|
      [CourseModuleUnitState::IN_PROGRESS, CourseModuleUnitState::NOT_PASSED].include?(unit.state(user))
    end
  end

  def self.user_units(user, course_id = nil)
    addition_query = if course_id.nil?
                       ''
                     else
                       "AND e.course_id = #{course_id}"
                     end
    ids = connection.exec_query(sanitize_sql_for_assignment([%{
      SELECT DISTINCT e.id AS id
      FROM (SELECT * FROM user_course_package_orders WHERE user_id = :user_id AND state = :state) a
      LEFT JOIN course_packages_user_course_package_orders b ON b.user_course_package_order_id = a.id
      LEFT JOIN course_packages c ON b.course_package_id = c.id
      LEFT JOIN course_module_units_packages d ON d.course_package_id = c.id
      LEFT JOIN course_module_units e ON d.course_module_unit_id = e.id
      WHERE
        c.active AND
        -- Проверим срок действия пакетов курса
        (
          c.validity_type IS NULL OR
          (
            -- Период
            (c.validity_type = 0 AND (NOW()::date BETWEEN c.start_date AND (c.start_date + c.validity))) OR
            -- Количество дней после покупки
            (c.validity_type = 1 AND NOW()::date < (a.created_at::date + c.validity))
          )
        )
        #{addition_query}
    }, user_id: user.id, state: OrderState::SUCCESS])).map { |item| item['id'] }
    where(id: ids)
  end

  # Завершает юнит модуля для пользователя.
  # @param user [User]: Модель пользователя.
  # @param payload [Hash]: Данные для завершения (например, кодовое слово для вебинара).
  def complete!(user, payload = nil)
    return false unless unit_content.check_complete_payload(payload)

    unit_result = user_result(user)
    unit_result.finished! unless unit_result.blank?
    true
  end

  # Возвращает состояние юнита модуля для пользователя.
  # @param user [User]: Модель пользователя.
  # @param params [Hash]: Хеш с доп. данными (для оптимизации).
  # @return [int]: Состояние юнита модуля для пользователя.
  def state(user, params={})
    unit_result = find_unit_result(user, params)
    if !unit_result.blank? && [CourseModuleUnitState::ON_CHECK,
                               CourseModuleUnitState::NOT_PASSED,
                               CourseModuleUnitState::REJECTED,
                               CourseModuleUnitState::FINISHED].include?(unit_result.state)
      unit_result.state
    elsif !start_date.nil? && DateTime.current < start_date
      CourseModuleUnitState::LOCKED
    elsif !deadline.nil? && DateTime.current > deadline
      CourseModuleUnitState::EXPIRED
    else
      CourseModuleUnitState::IN_PROGRESS
    end
  end

  def course
    self.course_module.course
  end

  # TODO: реализовать
  def has_subscription?(user)
    true
    # subscription = user.retrieve_subscription(course, self.module.start_date)
    # return false if subscription.nil?
    #
    # subscription_types.include?(subscription.subscription_type)
  end

  def decrement_serial_number!
    prev_unit = course_module.course_module_units.find_by(serial_number: serial_number - 1)
    return if prev_unit.nil?
    ActiveRecord::Base.transaction do
      prev_unit.update(serial_number: serial_number)
      update(serial_number: serial_number - 1)
    end
  end

  def increment_serial_number!
    next_unit = course_module.course_module_units.find_by(serial_number: serial_number + 1)
    return if next_unit.nil?
    ActiveRecord::Base.transaction do
      next_unit.update(serial_number: serial_number)
      update(serial_number: serial_number + 1)
    end
  end

  # Обновляет порядковый номер юнита в модуле
  def move!(new_module_id = course_module.id, _new_serial_number)
    new_module = CourseModule.find_by(id: new_module_id)
    raise StandardError.new('Модуль с указанным id не существует') if new_module.nil?
    ActiveRecord::Base.transaction do
      # Проверка _new_serial_number на корректность
      new_serial_number = if _new_serial_number >= 0 && _new_serial_number <= new_module.course_module_units.size
                            _new_serial_number
                          else
                            new_module.course_module_units.size
                          end
      # Если юнит перемещается в новый модуль, то считаем, что он был в конце списка юнитов
      old_serial_number = if new_module.id == course_module.id
                            serial_number
                          else
                            new_module.course_module_units.size
                          end
      moved_units_serial_numbers, added_number = if new_serial_number > old_serial_number
                                                   [(old_serial_number + 1..new_serial_number), -1]
                                                 else
                                                   [(new_serial_number..old_serial_number - 1), +1]
                                                 end
      update(course_module_id: new_module.id)
      units = course_module.course_module_units.where(serial_number: moved_units_serial_numbers)
      units.each { |unit| unit.update(serial_number: unit.serial_number + added_number) }
      update(serial_number: new_serial_number)
    end
  end

  # Возвращает результат юнита модуля для пользователя.
  # @param user [User]: Модель пользователя.
  # @param params [Hash]: Хеш с доп. данными (для оптимизации).
  # @return [CourseModuleUnitResult|nil]: Модель результата юнита модуля.
  def find_unit_result(user, params={})
    return params[:user_results].fetch(id, nil) unless params.blank? || params.fetch(:user_results, nil).nil?
    results.find_by(user: user) unless user.blank?
  end

  # Возвращает результат юнита модуля для пользователя. Если его нет, то он будет создан.
  # @param user [User]: Модель пользователя.
  # @return [CourseModuleUnitResult|nil]: Модель результата юнита модуля.
  def user_result(user)
    results.find_or_create_by(user: user, unit: self) unless user.blank?
  end

  def create_copy(course_module = self.course_module, reset_serial_number = false)
    self.deep_clone(preprocessor: ->(_original, kopy) {
      kopy.course_module = course_module
      kopy.serial_number = nil if reset_serial_number
      kopy.skip_unit_content_initialization = true
    }) do |original, kopy|
      kopy.unit_content = original.unit_content.create_copy
    end
  end

  private

  def init
    self.serial_number ||= course_module.course_module_units.length
    self.name ||= "Урок без имени #{serial_number + 1}"
    init_unit_content if self.unit_content.nil? && !self.skip_unit_content_initialization
  end

  def init_unit_content
    case unit_type
    when CourseModuleUnitType::VIDEO then self.unit_content = VideoUnit.new
    when CourseModuleUnitType::WEBINAR then self.unit_content = Webinar.new
    when CourseModuleUnitType::PRACTICE then self.unit_content = Practice.new
    when CourseModuleUnitType::TEXT then self.unit_content = TextUnit.new
    end
  end

  def recalculate_serial_numbers
    units = course_module.course_module_units
    ActiveRecord::Base.transaction do
      units.each_with_index { |unit, index| unit.update(serial_number: index) }
    end
  end
end
