class JrcBroker::WebhookDelivery
  class Unavailable < StandardError
    def initialize
      super('JRC_BROKER_DELIVERY_UNAVAILABLE')
    end
  end

  class ContextChanged < StandardError
    def initialize
      super('JRC_BROKER_DELIVERY_CONTEXT_CHANGED')
    end
  end

  def self.for(payload, webhook_type)
    return unless webhook_type == :api_inbox_webhook && payload[:event] == 'message_created'

    message = Message.find_by(id: payload[:id], message_type: :outgoing, private: false)
    return unless message && JrcBrokerInboxBinding.exists?(account_id: message.account_id, inbox_id: message.inbox_id)

    new(message)
  end

  def initialize(message)
    @message = message
  end

  def validate!(url:, secret:, delivery_id:)
    channel = @message.inbox.channel
    valid = channel.is_a?(Channel::Api) && channel.webhook_url == url && delivery_id.present? && secret.present? &&
            ActiveSupport::SecurityUtils.secure_compare(channel.secret.to_s, secret)
    raise ContextChanged unless valid
  end

  def retryable?(error)
    return true if error.is_a?(SafeFetch::FetchError) || error.is_a?(Errno::ECONNREFUSED) || error.is_a?(Errno::ECONNRESET)
    return false unless error.is_a?(SafeFetch::HttpError)

    status = error.message[/\A(\d{3})\b/, 1].to_i
    [408, 425, 429].include?(status) || (500..599).cover?(status)
  end

  def defer_campaign!(url:, payload:, webhook_type:, secret:, delivery_id:)
    id = @message.additional_attributes.to_h['jrc_campaign_broker_delivery_id']
    return false unless id

    delivery = JrcCampaigns::Delivery.find_by!(id: id, inbox_id: @message.inbox_id)
    raise ContextChanged unless delivery.metadata['message_id'] == @message.id && delivery.inbox.account_id == @message.account_id

    campaign = delivery.recipient.campaign.reload
    if campaign.canceled?
      Messages::StatusUpdateService.new(@message, 'failed', 'Campanha cancelada antes do envio.').perform
      return true
    end
    campaign.ensure_approved!
    reason = JrcCampaigns::EligibilityPolicy.new(account: campaign.account, phone_number: delivery.recipient.phone_number,
                                                 contact: delivery.recipient.contact, purpose: 'whatsapp_campaigns').list_rejection_reason
    raise ContextChanged if reason

    target = JrcCampaigns::ScheduleWindow.new(campaign).next_time(campaign.paused? ? 5.minutes.from_now : Time.current)
    return false unless campaign.paused? || target.future?

    WebhookJob.set(wait_until: target).perform_later(url, payload, webhook_type, secret: secret, delivery_id: delivery_id)
    true
  end

  def handle_failure(error)
    code = if error.is_a?(Unavailable) || error.is_a?(ContextChanged)
             error.message
           else
             'JRC_BROKER_DELIVERY_REJECTED'
           end
    # A late failed attempt must not overwrite delivery/read confirmation.
    Messages::StatusUpdateService.new(@message, 'failed', code).perform unless @message.reload.delivered? || @message.read?
    Rails.logger.warn("[JrcBroker::WebhookDelivery] #{code} message_id=#{@message.id}")
  end
end
