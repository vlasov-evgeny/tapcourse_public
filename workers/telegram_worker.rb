require_relative '../lib/telegram_bot'

class TelegramWorker
  include Sidekiq::Worker
  sidekiq_options retry: true, queue: 'default'

  NEW_ORDER = 1
  NEW_PHONE = 2

  TELEGRAM_BOT = TelegramBot.new(ENV['TELEGRAM_TOKEN'],
                                 Settings.telegram&.chats)

  def perform(action, payload_id)
    case action
    when NEW_ORDER then send_success_order_event(payload_id)
    when NEW_PHONE then send_new_phone_event(payload_id)
    end
  end

  private

  def send_success_order_event(payload_id)
    return unless Settings.integrations&.orders_notifications
    TELEGRAM_BOT.send_success_order_event(UserCoursePackageOrder.find(payload_id))
  end

  def send_new_phone_event(payload_id)
    return unless Settings.integrations&.new_users_notifications
    TELEGRAM_BOT.send_new_phone_event(User.find(payload_id))
  end
end