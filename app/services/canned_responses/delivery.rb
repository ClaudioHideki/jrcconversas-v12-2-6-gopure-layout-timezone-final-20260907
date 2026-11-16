require 'digest'

# One native Message, one optional attachment and one durable intent key.
class CannedResponses::Delivery
  class Invalid < StandardError; end

  MAX_CONTENT_LENGTH = {
    'Channel::FacebookPage' => 2000, 'Channel::Instagram' => 1000, 'Channel::Telegram' => 4096,
    'Channel::Tiktok' => 6000, 'Channel::Sms' => 320, 'Channel::Email' => 25_000, 'Channel::Whatsapp' => 4096
  }.freeze

  def initialize(response:, conversation:, user:)
    @response = response
    @conversation = conversation
    @user = user
    raise ActiveRecord::RecordNotFound unless response.account_id == conversation.account_id
  end

  def call(content:, key:, confirmed:, **review)
    raise Invalid, 'ACTOR_CHANGED' unless review.fetch(:expected_actor_id) == @user.id
    raise Invalid, 'CONFIRMATION_REQUIRED' unless confirmed == true
    raise Invalid, 'INVALID_DELIVERY_KEY' unless key.is_a?(String) && key.match?(/\A[a-zA-Z0-9_-]{16,80}\z/)

    validate_content!(content)
    intent = { content: content, key: key, revision: review.fetch(:revision), context: review.fetch(:expected_context) }
    with_upload { |upload, blob| persist(intent, upload, blob) }
  end

  private

  def validate_content!(content)
    raise Invalid, 'INVALID_CONTENT' unless content.is_a?(String) && content.present? && content.bytesize <= 65_536
    raise Invalid, 'CONTENT_TOO_LONG' if content.encode(Encoding::UTF_16LE).bytesize / 2 > max_content_length
    raise Invalid, 'UNRESOLVED_VARIABLES' if content.match?(%r{\[(nome|vendedor|empresa|cidade|região|data|produto/serviço)\]|\{\{|\{%})
  end

  def max_content_length
    inbox = @conversation.inbox
    return inbox.twilio_whatsapp? ? 1600 : 320 if inbox.twilio?

    MAX_CONTENT_LENGTH.fetch(inbox.channel_type, 10_000)
  end

  def with_upload
    return yield(nil, nil) unless @response.file.attached?

    blob = @response.file.blob
    # The checked native tempfile stays open through upload/after-commit callbacks.
    # Each message owns a copy independent of later model edits or deletion.
    blob.open do |file|
      upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: blob.filename.to_s, type: blob.content_type)
      yield(upload, blob)
    end
  rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
    raise Invalid, 'ATTACHMENT_UNAVAILABLE'
  end

  def persist(intent, upload, blob)
    @conversation.with_lock do
      @response.lock!
      previous = persisted_message(intent)
      next previous if previous

      validate_review!(intent, blob)
      CannedResponses::AttachmentPolicy.new(inbox: @conversation.inbox, blob: blob).validate! if blob
      create_message(intent, upload)
    end
  end

  def persisted_message(intent)
    old = @conversation.messages.where("additional_attributes -> 'quick_reply' ->> 'key' = ?", intent[:key]).first
    return unless old

    raise Invalid, 'DELIVERY_CONTENT_CHANGED' unless old.additional_attributes.dig('quick_reply', 'digest') == digest_for(intent)

    old
  end

  def digest_for(intent)
    Digest::SHA256.hexdigest([@response.id, intent[:revision], intent[:content], @user.id].to_json)
  end

  def validate_review!(intent, blob)
    validate_revision!(intent, blob)
    raise Invalid, 'CONTEXT_CHANGED' unless intent[:context] == CannedResponses::Preview.context_for(@conversation)
    raise Invalid, 'MESSAGE_WINDOW_CLOSED' unless @conversation.can_reply?
    raise Invalid, 'CHANNEL_REQUIRES_SEPARATE_MESSAGES' if @response.file.attached? && separate_media?
  end

  def validate_revision!(intent, blob)
    current_blob_id = @response.file.attached? ? @response.file.blob_id : nil
    raise Invalid, 'RESPONSE_CHANGED' unless intent[:revision] == @response.updated_at.iso8601(6) && current_blob_id == blob&.id
  end

  def separate_media?
    %w[Channel::Instagram Channel::Tiktok].include?(@conversation.inbox.channel_type) ||
      @conversation.additional_attributes['type'] == 'instagram_direct_message'
  end

  def create_message(intent, upload)
    values = { content: intent[:content], private: false, message_type: 'outgoing' }
    values[:attachments] = [upload] if upload
    message = Messages::MessageBuilder.new(@user, @conversation, values).perform
    message.update!(additional_attributes: (message.additional_attributes || {}).merge(
      'quick_reply' => { 'key' => intent[:key], 'digest' => digest_for(intent), 'response_id' => @response.id }
    ))
    message
  end
end
