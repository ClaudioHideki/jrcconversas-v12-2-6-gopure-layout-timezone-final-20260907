module WhatsappTemplateAuditable
  extend ActiveSupport::Concern

  included do
    before_save :capture_whatsapp_template_audit
  end

  private

  def capture_whatsapp_template_audit
    return unless inbox&.channel_type == 'Channel::Whatsapp' && !private? && (outgoing? || template?)
    return if additional_attributes&.dig('template_params').blank?

    data = (additional_attributes || {}).deep_dup
    audit = data['whatsapp_template_audit'] ||= {}
    params = data['template_params']
    audit['template_name'] ||= params['name']
    audit['language'] ||= params['language']
    audit['agent_id'] ||= sender_id if sender_type == 'User'
    audit['account_id'] ||= account_id
    audit['inbox_id'] ||= inbox_id
    audit['contact_id'] ||= conversation.contact_id
    audit['team_id'] ||= conversation.team_id
    audit['queued_at'] ||= (created_at || Time.current).iso8601
    audit['status'] = failed? ? 'failed' : (source_id.present? ? status : 'queued')
    if source_id.present?
      audit['provider_message_id'] = source_id
      audit['submitted_at'] ||= Time.current.iso8601
    end
    audit['delivered_at'] ||= Time.current.iso8601 if delivered? || read?
    audit['read_at'] ||= Time.current.iso8601 if read?
    if failed?
      audit['failed_at'] ||= Time.current.iso8601
      audit['error_code'] = external_error.to_s.split(':', 2).first
      audit['error_message'] = external_error.to_s.first(2000)
    end
    self.additional_attributes = data
  end
end
