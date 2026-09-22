# The permission to send a free-form message is independent of conversation status,
# agent activity, template delivery and pricing windows. No new DB columns required.
class Whatsapp::ConversationWindowService
  WINDOW_SECONDS = 24 * 60 * 60

  def initialize(conversation, now: Time.current)
    @conversation = conversation
    @now = now
  end

  def applicable?
    @conversation.inbox.channel_type == 'Channel::Whatsapp'
  end

  def can_send_free_message?
    applicable? && last_customer_message_at.present? &&
      last_customer_message_at <= @now && @now < expires_at
  end

  def last_customer_message_at
    return @last_customer_message_at if defined?(@last_customer_message_at)

    # A customer may have several tickets / phone and BSUID contact_inboxes.
    # Only messages FROM this customer TO this inbox in this account count.
    @last_customer_message_at = customer_messages.maximum(:created_at)
  end

  def expires_at
    last_customer_message_at && last_customer_message_at + WINDOW_SECONDS
  end

  def payload
    return nil unless applicable?

    open = can_send_free_message?
    {
      channel: @conversation.inbox.channel.provider == 'whatsapp_cloud' ? 'whatsapp_cloud_api' : 'whatsapp_360dialog',
      window_status: window_status,
      last_customer_message_at: last_customer_message_at&.iso8601,
      expires_at: expires_at&.iso8601,
      server_time: @now.iso8601,
      remaining_seconds: open ? [(expires_at - @now).floor, 0].max : 0,
      can_send_free_message: open,
      can_send_template: true,
      awaiting_customer_reply: !open && template_sent_after_customer?,
      supports_templates: true,
      has_service_window: true
    }
  end

  private

  def customer_messages
    # A contact may have multiple phone/BSUID links in the same inbox. Only the
    # link used by this conversation can open its WhatsApp service window.
    Message.joins(:conversation).where(account_id: @conversation.account_id, inbox_id: @conversation.inbox_id,
                  sender_type: 'Contact', sender_id: @conversation.contact_id,
                  message_type: :incoming, private: false)
           .where(conversations: { contact_inbox_id: @conversation.contact_inbox_id })
           .where.not(content_type: :voice_call)
           .where("COALESCE(content_attributes->>'whatsapp_window_timestamp_untrusted', 'false') <> 'true'")
  end

  def window_status
    return 'OPEN' if can_send_free_message?
    return 'UNKNOWN' if last_customer_message_at && last_customer_message_at > @now
    return 'TEMPLATE_REQUIRED' unless last_customer_message_at

    'CLOSED'
  end

  def template_sent_after_customer?
    sent_at = @conversation.messages.where(account_id: @conversation.account_id, private: false)
                           .where(message_type: [:outgoing, :template]).where.not(status: :failed)
                           .where.not(source_id: [nil, ''])
                           .where("additional_attributes->'template_params' IS NOT NULL").maximum(:created_at)
    sent_at.present? && (last_customer_message_at.nil? || sent_at > last_customer_message_at)
  end
end
