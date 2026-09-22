class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    validation = Whatsapp::OutgoingMessageGuard.new(message.conversation, user: message.sender).call(
      template_params: template_params, private_note: message.private?, message_type: message.message_type
    )
    if validation
      message.content = validation[:content]
      message.additional_attributes = (message.additional_attributes || {}).merge(
        'template_params' => validation[:template_params],
        'whatsapp_template_audit' => validation[:audit].merge(message.additional_attributes&.dig('whatsapp_template_audit') || {})
      )
    end
    return send_template_message if template_params.present?
    return send_session_message if message.conversation.can_reply?

    message.update!(status: :failed, external_error: I18n.t('errors.whatsapp.message_outside_messaging_window'))
  rescue Whatsapp::OutgoingMessageGuard::Error => e
    message.update!(status: :failed, external_error: "#{e.code}: #{e.message}")
    Rails.logger.warn("[WHATSAPP_SEND_BLOCKED] account_id=#{message.account_id} inbox_id=#{message.inbox_id} message_id=#{message.id} code=#{e.code}")
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    if message_id.present?
      message.update!(source_id: message_id)
    elsif !message.failed?
      message.update!(status: :failed, external_error: 'WHATSAPP_SEND_UNCONFIRMED: O provedor não confirmou o envio do modelo. Confira o histórico antes de tentar novamente.')
    end
  end

  def send_session_message
    message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
