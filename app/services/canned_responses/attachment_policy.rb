# Server-side counterpart of the existing editor's @chatwoot/utils upload rules.
# The catalog accepts the native formats; a direct delivery must also fit its inbox.
class CannedResponses::AttachmentPolicy
  DOCUMENT_TYPES = %w[
    text/plain application/pdf application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
  ].freeze
  IMAGE_TYPES = %w[image/jpeg image/png].freeze

  def initialize(inbox:, blob:)
    @inbox = inbox
    @blob = blob
  end

  def validate!
    limit = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit = 40 if limit <= 0
    allowed, channel_limit = channel_rules
    return if allowed.include?(@blob.content_type) && @blob.byte_size.positive? && @blob.byte_size <= [limit, channel_limit].compact.min.megabytes

    raise CannedResponses::Delivery::Invalid, 'ATTACHMENT_NOT_ALLOWED'
  end

  private

  CHANNEL_RULES = {
    'Channel::Whatsapp' => [IMAGE_TYPES + DOCUMENT_TYPES, 5, 100],
    'Channel::FacebookPage' => [IMAGE_TYPES + ['image/gif'] + DOCUMENT_TYPES, 8, 25],
    'Channel::Line' => [IMAGE_TYPES, 10, 10]
  }.freeze
  GENERAL_CHANNELS = %w[Channel::Api Channel::WebWidget Channel::Email Channel::Telegram Channel::Sms].freeze

  def channel_rules
    return twilio_rules if @inbox.channel_type == 'Channel::TwilioSms'
    return [%w[image/jpeg image/png image/webp image/gif] + Attachment::ACCEPTABLE_FILE_TYPES, nil] if GENERAL_CHANNELS.include?(@inbox.channel_type)

    types, image_limit, document_limit = CHANNEL_RULES.fetch(@inbox.channel_type, [[], 0, 0])
    [types, image? ? image_limit : document_limit]
  end

  def twilio_rules
    types = @inbox.twilio_whatsapp? ? IMAGE_TYPES + ['application/pdf'] : IMAGE_TYPES + Attachment::ACCEPTABLE_FILE_TYPES
    [types, 5]
  end

  def image?
    @blob.content_type.start_with?('image/')
  end
end
