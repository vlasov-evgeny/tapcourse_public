class Course < ApplicationRecord
  belongs_to :course_category, optional: true
  accepts_nested_attributes_for :course_category
  belongs_to :teacher, optional: true, class_name: 'User'
  has_many :course_mentors, dependent: :destroy
  has_many :mentors, through: :course_mentors, source: :user
  has_many :results, class_name: 'UserCourseResult', dependent: :destroy
  has_many :course_clans_users, dependent: :destroy
  has_many :course_clans
  has_many :course_user_mentors, dependent: :destroy
  has_many :course_package_groups, -> { order(:start_date).includes(:course_packages) }, dependent: :destroy
  has_many :course_modules, -> { order(:serial_number) }, dependent: :destroy
  has_one_attached :image

  validates_presence_of :name

  before_save do |course|
    if saved_change_to_settings?
      course.settings = saved_changes['settings'][0].deep_merge(saved_changes['settings'][1])
    end
  end

  after_save do
    if saved_change_to_settings? &&
      saved_changes['settings'].fetch(0, nil)&.fetch('integrations', nil)&.fetch('tilda', nil)&.fetch('page_id', nil) !=
        saved_changes['settings'].fetch(0, nil)&.fetch('integrations', nil)&.fetch('tilda', nil)&.fetch('page_id', nil)
      TildaWorker.perform_async(TildaWorker::SYNC_PAGE, tilda_page_id)
    end
  end

  after_save do |course|
    if image.attached? && (Time.now  - image.attachment.created_at) < 5
      CoursesWorker.perform_async(CoursesWorker::CALC_AVERAGE_COLOR, course.id)
    end
  end

  def short_name
    course_category&.name || name
  end

  def tilda_active?
    tilda_settings = settings.fetch('integrations', nil)&.fetch('tilda', nil)
    tilda_settings.present? && tilda_settings['active'] && tilda_settings['page_id'].present?
  end

  def tilda_page_id
    return nil unless tilda_active?

    settings.fetch('integrations', nil)&.fetch('tilda', nil)&.fetch('page_id', nil)
  end

  def teacher_telegram_active?
    telegram_settings = settings.fetch('integrations', nil)&.fetch('telegram', nil)
    telegram_settings.present? && telegram_settings['active'] && telegram_settings['teacher_bot_url'].present?
  end

  def teacher_telegram_url
    return nil unless teacher_telegram_active?

    settings.fetch('integrations', nil)&.fetch('telegram', nil)&.fetch('teacher_bot_url', nil)
  end

  def landing_url
    return nil unless tilda_active?
    page_id = tilda_page_id
    "#{ENV['TILDA_LANDING_ROOT']}/#{page_id}/#{page_id}.html"
  end

  def start_date
    course_package_groups.first&.start_date
  end

  def min_price
    course_package_groups
        .where(published: true)
        .map(&:course_packages)
        .flatten
        .select(&:published)
        .sort { |a, b| a.price <=> b.price }
        .first
        &.price
  end

  def self.user_courses(user)
    ids = connection.exec_query(sanitize_sql_for_assignment([%{
      SELECT DISTINCT cs.id AS id
      FROM user_course_package_orders as a
      LEFT JOIN course_packages_user_course_package_orders b ON b.user_course_package_order_id = a.id
      LEFT JOIN course_packages c ON b.course_package_id = c.id
      LEFT JOIN course_package_groups d ON c.course_package_group_id = d.id
      LEFT JOIN courses cs ON cs.id = d.course_id
      WHERE
        a.user_id = :user_id AND
        a.state = :state AND
        cs.published IS TRUE AND
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
    }, user_id: user.id, state: OrderState::SUCCESS])).map { |item| item['id'] }
    where(id: ids)
  end

  def user_clan(user)
    CourseClansUser.includes(:course_clan).find_by(user: user, course: self)&.course_clan
  end

  # Возвращает пользователей, который считаются сотрудниками для курса.
  # @return [Array<User>]: Список сотрудников для курса.
  def staff_users
    ([teacher] + mentors + User.admins).compact
  end

  # Возвращает рейтинг пользователей по курсу.
  # @return [UserRating]: Список рейтинга ользователей по курсу.
  def rating
    UserRating.where(course: self).order(:course_rating)
  end

  # Распределяет пользователей курса по кланам.
  def distribute_users_by_clans!
    students_without_clan = active_users.without_clan(self.id)
    return if students_without_clan.blank?
    clans = course_clans.order(members_count: :asc)
    return if clans.blank?
    # Если клан всего один, то добавим всех пользователей в него
    if clans.size == 1
      clans.first.add_users(students_without_clan)
      return
    end
    # Раскидаем пользователей по кланам
    until students_without_clan.blank?
      # clans_by_user_count уже отсортирован по количеству пользователей по возрастанию
      max_user_count = clans.last.members_count
      clans.each do |clan|
        break if students_without_clan.blank?
        if clan.members_count < max_user_count
          delta_user_count = max_user_count - clan.members_count
          clan.add_users(students_without_clan[0..delta_user_count])
          students_without_clan = students_without_clan[delta_user_count..]
        else
          # Если достигли максимума, то это самый большой клан, и нужно увеличить максимум
          # чтобы продолжать раскидывание пользователей
          max_user_count = clan.members_count + 1
        end
      end
    end
  end

  def course_module_units
    ids = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT DISTINCT units.id as id
      FROM course_modules
      LEFT JOIN course_module_units units ON course_modules.id = units.course_module_id
      WHERE
        course_modules.course_id = :course_id
    }, course_id: id])).map { |item| item['id'] }
    CourseModuleUnit.where(id: ids)
  end

  def results_summary(users, course_package_group)
    results = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT a.user_id as user_id,
        json_agg(json_build_object('course_module_unit_id', e.id, 'state', coalesce(f.state, -1))) as result
      FROM (SELECT * FROM user_course_package_orders WHERE user_id IN (:user_ids) AND state = :state) a
      LEFT JOIN course_packages_user_course_package_orders b ON b.user_course_package_order_id = a.id
      LEFT JOIN course_packages c ON b.course_package_id = c.id
      LEFT JOIN course_module_units_packages d ON d.course_package_id = c.id
      LEFT JOIN course_module_units e ON d.course_module_unit_id = e.id
      LEFT JOIN course_modules ee ON ee.id = e.course_module_id
      LEFT JOIN course_module_unit_results f ON f.unit_id = e.id AND f.user_id = a.user_id
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
        ) AND
        ee.course_id = :course_id AND
        c.course_package_group_id = :course_package_group_id
      GROUP BY a.user_id
    }, user_ids: users.map(&:id), state: OrderState::SUCCESS, course_id: id,
      course_package_group_id: course_package_group.id]))
    results.each do |result|
      result['result'] = JSON.parse(result['result']).uniq {|e| e['course_module_unit_id'] }
    end
    results
  end

  def active_users
    course_package_ids = course_package_groups
      .includes(:course_packages)
      .where(%{
        (course_package_groups.start_date IS NOT NULL AND NOW()::date >= course_package_groups.start_date OR
         course_package_groups.start_date IS NULL) AND (course_package_groups.end_date IS NOT NULL AND
        NOW()::date <= course_package_groups.end_date OR course_package_groups.end_date IS NULL) })
      .map(&:course_packages).flatten
      .map(&:id)
    ids = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT DISTINCT b.user_id AS id
      FROM (SELECT * FROM course_packages_user_course_package_orders
            WHERE course_package_id IN (:course_package_ids)) a
      LEFT JOIN user_course_package_orders b ON a.user_course_package_order_id = b.id
      WHERE b.state = :state
    }, state: OrderState::SUCCESS, course_package_ids: course_package_ids])).map { |item| item['id'] }
    User.where(id: ids)
  end
end
