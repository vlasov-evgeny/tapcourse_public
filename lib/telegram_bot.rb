require 'telegram/bot'

class TelegramBot
  def initialize(token, chats = {})
    @token = token
    @chats = chats
  end

  def send_success_order_event(order)
    return if @chats[:orders_chat].nil?

    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_message(chat_id: @chats[:orders_chat],
                           text: order.text_summary)
    end
  end

  def send_new_phone_event(user)
    return if @chats[:users_chat].nil?

    Telegram::Bot::Client.run(@token) do |bot|
      bot.api.send_message(chat_id: @chats[:users_chat],
                           text: "Новый телефон:\nПользователь: #{user.full_name}\n"\
                                 "Контактные данные: #{user.user_url}\nТелефон: #{user.phone}")
    end
  end
end