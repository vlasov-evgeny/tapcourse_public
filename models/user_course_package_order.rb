require 'erb'
require_relative '../lib/acquiring'
require_relative '../lib/telegram_bot'

class UserCoursePackageOrder < ApplicationRecord
  self.implicit_order_column = 'created_at'
  attr_accessor :skip_telegram
  attr_accessor :skip_google_drive

  belongs_to :user, optional: true
  belongs_to :coupon, optional: true
  belongs_to :creator, class_name: 'User'
  has_and_belongs_to_many :course_packages, -> { includes(:course_package_group) }
  has_enumeration_for :state, with: OrderState, create_helpers: true, required: true

  attr_accessor :integrations_queue

  validate :need_email_or_phone
  before_validation :init
  after_create_commit :create_payment
  after_save :set_integrations_queue
  after_save :find_and_join_user
  after_save_commit :exec_integrations

  scope :by_user, ->(user_id) { where(user_id: user_id).order(created_at: :desc) }
  scope :by_creator, ->(user_id) { where('creator_id = ? AND user_id <> ?', user_id, user_id)
                                       .order(created_at: :desc) }

  include PgSearch::Model
  pg_search_scope :search,
                  against: [:phone_number, :username],
                  using: { tsearch: { prefix: true } }

  def self.calc_price(course_packages, coupon = nil)
    return 0 if course_packages.blank?

    price = calc_full_price(course_packages)
    coupon = choose_coupon(course_packages, coupon, price)
    coupon&.apply_discount(price) || price
  end

  def self.calc_full_price(course_packages)
    course_packages.inject(0) { |sum, item| sum + item.price }
  end

  def self.choose_coupon(course_packages, coupon, price)
    return nil if course_packages.blank?

    if coupon.nil? || !coupon.available?(course_packages)
      coupon = Coupon.find_best_auto_coupon(course_packages)
    else
      auto_coupon = Coupon.find_best_auto_coupon(course_packages)
      coupon = auto_coupon if !auto_coupon.nil? && auto_coupon.apply_discount(price) < coupon.apply_discount(price)
    end
    coupon
  end

  def self.worksheet_num_by_state(order_state)
    case order_state
    when OrderState::SUCCESS then 0
    when OrderState::REJECTED then 1
    when OrderState::CANCELED then 2
    else 3
    end
  end

  def self.reload_spreadsheets
    GoogleDriveWorker.perform_async(GoogleDriveWorker::RELOAD_ORDERS)
  end

  def success!
    update(state: OrderState::SUCCESS)
  end

  def reject!
    update(state: OrderState::REJECTED)
  end

  def courses
    course_ids = course_packages.map do |course_package|
      course_package.course_package_group.course_id
    end
    Course.where(id: course_ids)
  end

  def discount
    [0, self.class.calc_full_price(course_packages) - price].max
  end

  def order_phone
    if phone_number.present?
      phone_number
    elsif user.present?
      user.phone
    end
  end

  def order_email
    if email.present?
      email
    elsif user.present?
      user.email
    end
  end

  def course_packages_full_names
    course_packages.map(&:full_name).join(', ')
  end

  def text_summary
    ERB.new(%{
Заказ #{created_at}
Покупатель: #{user.full_name}
Контактные данные: #{user.user_url}
Купленные курсы:
<% for item in course_packages %>
  *<%= item.full_name %>
<% end  %>
Итого: #{price} руб.
    }).result(binding)
  end

  def self.spreadsheet_header
    [
        'ID',
        'URL',
        'ID користувача',
        'tg_id',
        'ПІБ',
        'Посилання на користувача',
        'Email',
        'Номер телефону',
        'Дата створення',
        'Куплені курси',
        'Кінцева ціна',
        'Купон',
        'Зовнішня оплата',
        'Коментар до замовлення'
    ]
  end

  def to_spreadsheets_row
    [
        id.to_s,                     # ID заказа
        ENV['PAYMENT_SUCCESS_URL'].gsub('{ORDER_ID}', id.to_s), # URL Заказа
        user&.id,                    # ID пользователя
        user&.uid,                    # ID пользователя
        user&.full_name,             # ФИО
        user&.user_url,              # Ссылка на пользователя
        order_email,                 # Почта
        order_phone,                 # Телефон
        created_at.to_s,             # Дата создания
        course_packages_full_names,  # Названия курсов в пакете
        price&.to_s || '0',          # Итоговая цена
        coupon.try(:code)&.to_s,     # Купон
        external_payment,            # Оплачен не на платформе
        description                  # Комментарий к заказу
    ]
  end

  def need_pay?
    !external_payment && price > 0
  end

  def self.search_by_user(user)
    orders = []
    orders += where(user: user)
    orders += where('user_id IS NULL AND phone_number is NOT NULL AND phone_number = ?', user.phone) if user.phone.present?
    orders += search(user.screen_name).where(user_id: nil) if user.screen_name.present?
    orders += search(user.full_name).where(user_id: nil)
    orders.uniq { |order| order.id }
  end

  def join_user(user)
    return if self.user.present?

    self.user = user
    if need_pay?
      self.state = OrderState::NEW
    else
      self.state = OrderState::SUCCESS
    end
    save
    create_payment
  end

  private

  def init
    self.creator ||= user
    if price.nil?
      self.coupon = self.class.choose_coupon(course_packages, coupon, self.class.calc_full_price(course_packages))
      self.price = self.class.calc_price(course_packages, coupon)
    else
      self.coupon = nil
    end
    self.email ||= user&.email
    self.state = OrderState::WAITING_JOIN_USER if user.nil?
  end

  def create_payment
    if price.zero? || external_payment?
      success! if user.present?
      return
    end
    return if user.nil?

    payment_data = Acquiring.create_payment(Settings.payments&.provider,
                                            self,
                                            Settings.payments&.providers[Settings.payments&.provider])
    update(payment_data: payment_data)
  end

  def need_email_or_phone
    return if price.zero?
    return if !Settings.payments&.providers[Settings.payments&.provider].need_contact ||
        order_phone.present? || order_email.present?

    errors.add(:email, 'Телефон или email должны быть заполнены')
    errors.add(:phone, 'Телефон или email должны быть заполнены')
  end

  def find_and_join_user
    return if user.present? || (phone_number.blank? && username.blank?)

    query = "#{(phone_number || '')} #{username}"
    user = User.search_by_query(query).first
    join_user(user) if user.present?
  end

  private

  def set_integrations_queue
    @integrations_queue = {}
    if (saved_change_to_state? || saved_change_to_id?) && success?
      @integrations_queue[:telegram] = [TelegramWorker::NEW_ORDER]
    end
    if saved_change_to_id?
      @integrations_queue[:google] = [GoogleDriveWorker::ADD_ORDER]
    elsif saved_change_to_state?
      @integrations_queue[:google] = [GoogleDriveWorker::MOVE_ORDER]
    end
  end

  def exec_integrations
    return if @integrations_queue.blank?

    if @integrations_queue[:telegram].present? && !skip_telegram
      send_telegram_event(@integrations_queue[:telegram])
    end
    if @integrations_queue[:google].present? && !skip_google_drive
      write_to_google_drive(@integrations_queue[:google])
    end
  end

  def send_telegram_event(actions)
    actions.each { |action| TelegramWorker.perform_async(action, id) }
  end

  def write_to_google_drive(actions)
    actions.each { |action| GoogleDriveWorker.perform_async(action, id) }
  end
end
