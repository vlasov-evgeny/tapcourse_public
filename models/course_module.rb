class CourseModule < ApplicationRecord
  belongs_to :course
  has_many :course_module_units, -> { order(:serial_number) }, dependent: :destroy
  validates_presence_of :name

  scope :published, -> { where(published: true) }

  before_create :setup_serial_number
  after_destroy :recalculate_serial_numbers

  # Возвращает состояние модуля для пользователя.
  # @param user [User]: Модель пользователя.
  # @return [CourseModuleUnitState]: Состояние модуля для пользователя.
  def state(user, units = nil, results = nil)
    units ||= course_module_units
    units = units.to_a.select { |unit| unit.course_module_id == id }
    unit_ids = units.map(&:id)
    if results.present?
      results = results.select { |unit_id, _result| unit_ids.include?(unit_id) }
    else
      results ||= CourseModuleUnitResult.where(user: user, unit_id: unit_ids).map do |result|
        [result.unit_id, result]
      end.to_h
    end

    finished_count = results.values.count { |result| result.finished? }

    state = if units.count.zero? || !published
              CourseModuleState::LOCKED
            elsif units.all? { |unit| unit.state(user, { user_results: results }) == CourseModuleUnitState::FINISHED }
              CourseModuleState::FINISHED
            elsif units.all? { |unit| unit.state(user, { user_results: results }) == CourseModuleUnitState::LOCKED }
              CourseModuleState::LOCKED
            else
              CourseModuleState::IN_PROGRESS
            end
    { state: state, total_count: units.size, finished_count: finished_count }
  end

  def decrement_serial_number!
    prev_course_module = course.course_modules.find_by(serial_number: serial_number - 1)
    return if prev_course_module.nil?
    ActiveRecord::Base.transaction do
      prev_course_module.update(serial_number: serial_number)
      update(serial_number: serial_number - 1)
    end
  end

  def increment_serial_number!
    next_course_module = course.course_modules.find_by(serial_number: serial_number + 1)
    return if next_course_module.nil?
    ActiveRecord::Base.transaction do
      next_course_module.update(serial_number: serial_number)
      update(serial_number: serial_number + 1)
    end
  end

  # Обновляет порядковый номер модуля
  def move!(_new_serial_number)
    ActiveRecord::Base.transaction do
      # Проверка _new_serial_number на корректность
      new_serial_number = if _new_serial_number >= 0 && _new_serial_number <= course.course_modules.size
                            _new_serial_number
                          else
                            course.course_modules.size
                          end
      moved_modules_serial_numbers, added_number = if new_serial_number > serial_number
                                                   [(serial_number + 1..new_serial_number), -1]
                                                 else
                                                   [(new_serial_number..serial_number - 1), +1]
                                                 end
      modules = course.course_modules.where(serial_number: moved_modules_serial_numbers)
      modules.each { |courseModule| courseModule.update(serial_number: courseModule.serial_number + added_number) }
      update(serial_number: new_serial_number)
    end
  end

  def create_copy(course = self.course)
    deep_clone(preprocessor: ->(_original, kopy) { kopy.course = course }) do |original, kopy|
      kopy.course_module_units = original.course_module_units.map(&:create_copy)
    end
  end

  private

  def setup_serial_number
    self.serial_number = course.course_modules.length
  end

  def recalculate_serial_numbers
    modules = course.course_modules
    ActiveRecord::Base.transaction do
      modules.each_with_index { |course_module, index| course_module.update(serial_number: index) }
    end
  end
end
