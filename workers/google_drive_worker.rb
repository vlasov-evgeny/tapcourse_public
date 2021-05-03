require_relative '../lib/google_drive_api'

class GoogleDriveWorker
  include Sidekiq::Worker
  sidekiq_options retry: true, queue: 'google_drive'

  ADD_ORDER = 1
  MOVE_ORDER = 2
  RELOAD_ORDERS = 3
  ADD_USER = 4
  RELOAD_USERS = 5
  UPDATE_USER = 6

  ORDERS_TABLE = GoogleDriveApi.new(Settings.google_drive&.credentials,
                                    Settings.google_drive&.orders&.spreadsheet_id,
                                    id_column_name=Settings.google_drive&.orders&.id_column_name)
  USERS_TABLE = GoogleDriveApi.new(Settings.google_drive&.credentials,
                                   Settings.google_drive&.users&.spreadsheet_id,
                                   id_column_name=Settings.google_drive&.users&.id_column_name)

  def perform(action, payload_id = nil)
    return unless Settings.integrations&.google_drive_sync

    case action
    when ADD_ORDER then add_order(payload_id)
    when MOVE_ORDER then move_order(payload_id)
    when RELOAD_ORDERS then reload_orders
    when ADD_USER then add_user(payload_id)
    when RELOAD_USERS then reload_users
    when UPDATE_USER then update_user(payload_id)
    end
  end

  private

  def add_order(payload_id)
    user_order = UserCoursePackageOrder.find(payload_id)
    return if user_order.blank?
    ORDERS_TABLE.worksheet_num = UserCoursePackageOrder.worksheet_num_by_state(user_order.state)
    ORDERS_TABLE.insert_row!(user_order.to_spreadsheets_row)
  end

  def move_order(payload_id)
    user_order = UserCoursePackageOrder.find(payload_id)
    return if user_order.blank?

    ORDERS_TABLE.worksheet_num = UserCoursePackageOrder.worksheet_num_by_state(user_order.state)
    ORDERS_TABLE.insert_row!(user_order.to_spreadsheets_row)
    ORDERS_TABLE.worksheet_num = UserCoursePackageOrder.worksheet_num_by_state(user_order.state_before_last_save)
    ORDERS_TABLE.delete_row_by_id!(user_order.id)
  end

  def reload_orders
    ORDERS_TABLE.reset_worksheets!(UserCoursePackageOrder.spreadsheet_header)
    ORDERS_TABLE.session do
      UserCoursePackageOrder.find_each(batch_size: 1000) do |user_order|
        ORDERS_TABLE.worksheet_num = UserCoursePackageOrder.worksheet_num_by_state(user_order.state)
        ORDERS_TABLE.insert_row(user_order.to_spreadsheets_row)
      end
    end
  end

  def add_user(user_id)
    user = User.find(user_id)
    return if user.blank?

    USERS_TABLE.insert_row!(user.to_spreadsheets_row)
  end

  def update_user(user_id)
    user = User.find(user_id)
    return if user.blank?

    USERS_TABLE.update_row_by_id!(user.to_spreadsheets_row, user.id)
  end

  def reload_users
    USERS_TABLE.reset_worksheets!(User.spreadsheet_header)
    USERS_TABLE.session do
      User.find_each(batch_size: 1000) do |user|
        USERS_TABLE.insert_row(user.to_spreadsheets_row)
      end
    end
  end
end