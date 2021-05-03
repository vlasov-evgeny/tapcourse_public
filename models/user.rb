class User < ApplicationRecord
  include Rails.application.routes.url_helpers

  has_many :course_mentors, dependent: :destroy
  has_many :supervised_courses, through: :course_mentors, source: :course
  has_many :course_user_mentors, dependent: :destroy
  has_many :user_course_results, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :course_clans_users, dependent: :destroy
  has_many :course_clans, through: :course_clans_users
  has_many :user_course_package_orders
  has_many :salebot_clients
  has_enumeration_for :role, with: UserRoleType, create_helpers: true, required: true
  has_enumeration_for :provider, with: AuthProvider, create_helpers: true, required: true
  has_one_attached :letter_avatar

  attr_accessor :integrations_queue

  # Возвращает пользователей - администраторов.
  scope :admins, -> { where(role: [UserRoleType::ADMIN, UserRoleType::SUPER_ADMIN]) }
  scope :staff, -> {
    where(role: [UserRoleType::ADMIN, UserRoleType::TEACHER, UserRoleType::SUPER_ADMIN, UserRoleType::SELLER])
  }
  scope :gods, -> { where('(provider = "vk" AND uid IN ?) OR (provider = "telegram" AND screen_name IN ?)',
                          Settings.auth&.admins&.vk, Settings.auth&.admins&.telegram) }
  # Список учеников курса
  def self.course_students(course_id)
    ids = connection.exec_query(sanitize_sql_for_assignment([%{
      SELECT DISTINCT a.user_id AS id
      FROM user_course_package_orders as a
      LEFT JOIN course_packages_user_course_package_orders b ON b.user_course_package_order_id = a.id
      LEFT JOIN course_packages c ON b.course_package_id = c.id
      LEFT JOIN course_package_groups d ON c.course_package_group_id = d.id
      LEFT JOIN courses cs ON cs.id = d.course_id
      WHERE cs.id = :course_id AND a.state = :state
    }, course_id: course_id, state: OrderState::SUCCESS])).map { |item| item['id'] }
    where(id: ids)
  end
  # Список учеников курса без клана
  scope :without_clan, -> (course_id) {
    where(%{
        NOT EXISTS (SELECT 1
                    FROM course_clans_users
                    LEFT JOIN course_clans ON course_clans.id = course_clans_users.course_clan_id
                    WHERE course_clans.course_id = ? AND users.id = course_clans_users.user_id
                    LIMIT 1)
    }, course_id) }

  after_save :set_integrations_queue
  after_save :join_orders
  after_save_commit :exec_integrations

  include PgSearch::Model
  pg_search_scope :search,
                  against: [:name, :last_name, :screen_name, :uid, :phone],
                  using: { tsearch: { prefix: true } }

  def self.search_by_query(query)
    return where('') if query.blank?

    query = if VkApi.vk_page?(query)
              VkApi.extract_vk_id(query)[:vk_id]
            elsif query.start_with?('@') || query.start_with?('+')
              query[1..-1]
            else
              query
            end
    search(query)
  end

  def image
    return self['image'] if self['image'].present?
    return '' unless letter_avatar.attached?

    rails_blob_path(self.letter_avatar, disposition: "attachment", only_path: true)
  end

  def user_url
    if vk?
      "https://vk.com/id#{uid}"
    elsif telegram? && screen_name
      "https://t.me/#{screen_name}"
    else
      nil
    end
  end

  def self.spreadsheet_header
    [
        'ID',
        'ПІБ',
        'Посилання на користувача',
        'tg_id',
        'Email',
        'Номер телефону',
        'Дата реєстрації',
        'utm_source',
        'utm_medium',
        'utm_campaign',
        'utm_term',
        'utm_content',
        'Salebot tags',
        'Salebot date_of_creation'
    ]
  end

  def to_spreadsheets_row
    [
        id.to_s,               # ID
        full_name,             # ФИО
        user_url,              # Ссылка на пользователя
        uid,                   # id в провайдере авторизации
        email,                 # Почта
        phone,                 # Телефон
        created_at.to_s,       # Дата создания
        utm&.fetch('utm_source', nil),
        utm&.fetch('utm_medium', nil),
        utm&.fetch('utm_campaign', nil),
        utm&.fetch('utm_term', nil),
        utm&.fetch('utm_content', nil),
        salebot_tags&.join(' | '),
        salebot_date_of_creation&.strftime('%d.%m.%Y')
    ]
  end

  def self.reload_spreadsheets
    GoogleDriveWorker.perform_async(GoogleDriveWorker::RELOAD_USERS)
  end

  def full_name
    [name, last_name].select(&:present?).join(' ')
  end

  def ability_rules
    ApplicationPolicy::RESOURCES.map do |resource|
      [resource, Pundit.policy(self, resource.constantize)&.class_ability || []]
    end.to_h.merge('Global' =>  GlobalPolicy.new(self).class_ability)
  end

  def need_phone_or_email?
    phone.blank? && email.blank?
  end

  def has_course_package?(course_package)
    ids = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT DISTINCT b.course_package_id AS id
      FROM (SELECT * FROM user_course_package_orders WHERE user_id = :user_id AND state = :state) a
      LEFT JOIN course_packages_user_course_package_orders b ON b.user_course_package_order_id = a.id
    }, user_id: id, state: OrderState::SUCCESS])).map { |item| item['id'].to_s }
    ids.include?(course_package.id.to_s)
  end

  def self.register_by_vk(vk_id)
    user_attrs = fetch_vk_data(vk_id)
    User.find_or_create_by!(uid: user_attrs[:uid]) do |user|
      user.assign_attributes(user_attrs)
    end
  end

  def authorized?
    !self.id.nil?
  end

  def reset_role!
    update(role: UserRoleType::GUEST)
  end

  # Проверяет, является ли пользователь ментором курса.
  # @return bool: Является ли пользователя ментором курса.
  def course_mentor?(course)
    mentor? || supervised_courses.include?(course)
  end

  # Проверяет, является ли пользователь преподователем курса.
  # @return bool: Является ли пользователя преподователем курса.
  def course_teacher?(course)
    teacher? && course.teacher == self
  end

  # Проверяет, есть ли у пользователя права сотрудника для курса.
  # @return bool: Есть ли у пользователя права сотрудника для курса.
  def course_staff?(course)
    god? || admin? || course_teacher?(course) || course_mentor?(course)
  end

  # Проверяет, есть ли у пользователя права сотрудника.
  # @return bool: Есть ли у пользователя права сотрудника.
  def staff?
    god? || admin? || teacher? || mentor? || seller?
  end

  # Проверяет, есть ли у пользователя абсолютные права.
  # @return bool: Есть ли абсолютные права.
  def god?
    vk? && Settings.auth&.admins&.vk&.include?(uid) ||
        telegram? && Settings.auth&.admins&.telegram&.include?(screen_name)
  end

  # Проверяет, состоит ли пользователь в каком-либо клане.
  # @param course: Курс.
  # @return [bool]: Состоит ли в каком-либо клане.
  def clan?(course)
    CourseClansUser.exists?(user: self, course: course)
  end

  # Возвращает клан, в котором состоит пользователь по курсу.
  # @param course [Course]: Модель курса.
  # @return [CourseClan|nil]: Модель клана.
  def clan(course)
    course_clan_user = CourseClansUser.find_by(user: self, course: course)
    return if course_clan_user.nil?
    course_clan_user.clan
  end

  def self.fetch_vk_data(vk_id)
    vk_api = VkApi.new(ENV['VK_SERVICE_KEY'])
    data = vk_api.get_user_info(vk_id)
    raise(ExceptionHandler::VkError, 'Информация о пользователе не найдена') if data.nil?
    data
  end

  def join_orders
    if saved_change_to_id? || (saved_change_to_phone? && phone.present?)
      UserCoursePackageOrder.search_by_user(self).each do |order|
        order.join_user(self)
      end
    end
  end

  def has_paid_courses?
    user_course_package_orders.where('price > 0 OR external_payment IS TRUE').count > 0
  end

  def sync_salebot_tags!
    SalebotClient.attach_clients_to_user!(self)
    reload
    tags = salebot_clients.map { |client| client.variables['tag'] }.compact.uniq
    date_of_creation = salebot_clients.map do |client|
      client.variables['date_of_creation']&.to_date
    end.compact.sort.first
    update(salebot_tags: tags, salebot_date_of_creation: date_of_creation)
  end

  private

  def set_integrations_queue
    @integrations_queue = {}
    if (saved_change_to_phone? || saved_change_to_id?) && phone.present?
      @integrations_queue[:telegram] = [TelegramWorker::NEW_PHONE]
    end
    if saved_change_to_id?
      @integrations_queue[:google] = [GoogleDriveWorker::ADD_USER]
    elsif saved_change_to_salebot_tags? && salebot_tags.present?
      @integrations_queue[:google] = [GoogleDriveWorker::UPDATE_USER]
    end
    if new_record? || saved_change_to_last_name? || saved_change_to_name?
      @integrations_queue[:avatar] = true
    end
    if saved_change_to_id?
      @integrations_queue[:salebot] = true
    end
  end

  def exec_integrations
    return if @integrations_queue.blank?

    send_telegram_event(@integrations_queue[:telegram]) if @integrations_queue[:telegram].present?
    write_to_google_drive(@integrations_queue[:google]) if @integrations_queue[:google].present?
    generate_avatar if @integrations_queue[:avatar]
    fetch_salebot_tags if @integrations_queue[:salebot]
  end

  def send_telegram_event(actions)
    actions.each { |action| TelegramWorker.perform_async(action, id) }
  end

  def write_to_google_drive(actions)
    actions.each { |action| GoogleDriveWorker.perform_async(action, id) }
  end

  def generate_avatar
      image_path = LetterAvatar.generate(full_name, 200)
      letter_avatar.attach(io: File.open(Rails.root.join(image_path)), filename: 'avatar')
  end

  def fetch_salebot_tags
    SalebotWorker.perform_async(SalebotWorker::FETCH_USER_TAGS, id)
  end
end
