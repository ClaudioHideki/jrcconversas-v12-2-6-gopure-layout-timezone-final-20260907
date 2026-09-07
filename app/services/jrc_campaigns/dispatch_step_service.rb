class JrcCampaigns::DispatchStepService
  def initialize(recipient:, step:)
    @recipient = recipient
    @step = step
    @campaign = recipient.campaign
    @inbox = recipient.inbox
  end

  def perform
    return if campaign.canceled?
    if campaign.paused?
      recipient.update!(metadata: recipient.metadata.to_h.merge('pending_step_id' => step.id))
      return
    end
    return if recipient.status.in?(%w[failed canceled skipped])
    return if recipient.deliveries.where(step: step, status: %w[sent delivered read failed]).exists?

    recipient.update!(metadata: recipient.metadata.to_h.except('pending_step_id')) if recipient.metadata.to_h.key?('pending_step_id')
    if step.only_if_no_reply? && recipient.replied_at.present?
      JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
      return
    end

    recipient.update!(status: 'processing') if recipient.queued?
    delivery = recipient.deliveries.find_or_initialize_by(step: step)
    delivery.inbox = inbox
    delivery.status = 'queued' if delivery.new_record?
    delivery.save!

    dispatch_result = dispatch_message(delivery)
    external_id = dispatch_result.is_a?(Hash) ? dispatch_result[:external_id] : dispatch_result
    raise 'O provedor não retornou o identificador da mensagem' if external_id.blank?

    now = Time.current
    delivery.update!(external_id: external_id, status: 'sent', sent_at: now, error_message: nil)
    recipient.update!(status: 'sent', sent_at: recipient.sent_at || now, error_message: nil)
    JrcCampaigns::EventLogger.call(
      campaign: campaign,
      execution: recipient.execution,
      recipient: recipient,
      event_type: 'message_sent',
      payload: { step_id: step.id, external_id: external_id, inbox_id: inbox.id, kind: step.kind }
    )
    unless campaign.email?
      attach_existing_conversation
      create_conversation_if_requested
      record_conversation_message(delivery, external_id)
    end
    schedule_next_step_or_finish
  rescue StandardError => e
    fail_delivery(e)
  end

  private

  attr_reader :recipient, :step, :campaign, :inbox

  def dispatch_message(delivery)
    return dispatch_email(delivery) if campaign.email?

    channel = inbox.channel
    raise 'A caixa selecionada não é WhatsApp' unless channel.is_a?(Channel::Whatsapp)

    if step.kind == 'template'
      send_template(channel)
    else
      ensure_freeform_allowed!
      body = renderer.render(effective_value('body', step.body))
      proxy = JrcCampaigns::ProviderMessageProxy.new(
        kind: step.kind,
        body: body,
        media_url: effective_value('media_url', step.media_url),
        file_name: effective_value('file_name', step.file_name)
      )
      external_id = channel.send_message(recipient.phone_number, proxy)
      raise proxy.external_error if external_id.blank? && proxy.external_error.present?

      external_id
    end
  end

  def dispatch_email(delivery)
    result = JrcCampaigns::EmailSender.new(
      account: campaign.account,
      user: campaign.created_by,
      inbox: inbox,
      email: recipient.email,
      name: recipient.name,
      subject: renderer.render(effective_value('subject', step.subject)),
      body: renderer.render(effective_value('body', step.body)),
      media_asset_id: effective_value('media_asset_id', step.media_asset_id),
      conversation: recipient.conversation,
      conversation_status: email_conversation_status,
      additional_attributes: {
        'campaign_id' => campaign.id,
        'jrc_campaign_id' => campaign.id,
        'jrc_campaign_execution_id' => recipient.execution_id,
        'jrc_campaign_step_id' => step.id
      }
    ).perform
    recipient.update!(contact: result[:contact], conversation: result[:conversation])
    delivery.update!(metadata: delivery.metadata.to_h.merge('message_id' => result[:message].id))
    result
  end

  def email_conversation_status
    campaign.conversation_mode == 'open' ? 'open' : 'pending'
  end

  def send_template(channel)
    raw_params = effective_value('template_params', step.template_params).deep_dup
    raw_params['name'] = effective_value('template_name', step.template_name)
    raw_params['namespace'] = effective_value('template_namespace', step.template_namespace)
    raw_params['language'] = effective_value('template_language', step.template_language)
    rendered_params = renderer.render(raw_params)
    name, namespace, lang_code, parameters = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: rendered_params
    ).call
    raise 'Template não aprovado ou não encontrado na caixa selecionada' if name.blank?

    proxy = JrcCampaigns::ProviderMessageProxy.new(kind: 'text', body: '')
    external_id = channel.send_template(
      recipient.phone_number,
      { name: name, namespace: namespace, lang_code: lang_code, parameters: parameters },
      proxy
    )
    raise proxy.external_error if external_id.blank? && proxy.external_error.present?

    external_id
  end

  def ensure_freeform_allowed!
    contact = recipient.contact
    raise 'Mensagem livre exige contato existente; use template para o primeiro contato' unless contact

    conversation = contact.conversations.where(inbox_id: inbox.id).order(updated_at: :desc).first
    raise 'Mensagem livre fora da janela de atendimento; use template aprovado da Meta' unless conversation
    unless Conversations::MessageWindowService.new(conversation).can_reply?
      raise 'Mensagem livre fora da janela de atendimento; use template aprovado da Meta'
    end

    recipient.update!(conversation: conversation) unless recipient.conversation_id == conversation.id
  end

  def renderer
    @renderer ||= JrcCampaigns::TemplateRenderer.new(recipient: recipient, inbox: inbox)
  end

  def effective_value(key, fallback)
    override = step.inbox_overrides.to_h[inbox.id.to_s] || step.inbox_overrides.to_h[inbox.id]
    override&.fetch(key, nil).presence || fallback
  end

  def schedule_next_step_or_finish
    next_step = campaign.steps.where('position > ?', step.position).order(:position).first
    if next_step
      wait_time = if next_step.only_if_no_reply? && next_step.follow_up_after_hours.present?
                    next_step.follow_up_after_hours.hours
                  else
                    step.delay_after_seconds.seconds
                  end
      target_time = JrcCampaigns::ScheduleWindow.new(campaign).next_time(Time.current + wait_time)
      JrcCampaigns::DispatchStepJob.set(wait_until: target_time).perform_later(recipient.id, next_step.id)
    else
      JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
    end
  end

  def attach_existing_conversation
    return if recipient.conversation_id.present? || recipient.contact.blank?

    conversation = recipient.contact.conversations.where(inbox_id: inbox.id).order(updated_at: :desc).first
    recipient.update!(conversation: conversation) if conversation
  end

  def record_conversation_message(delivery, external_id)
    conversation = recipient.conversation
    return unless conversation

    message = conversation.messages.build(
      account: campaign.account,
      inbox: inbox,
      sender: nil,
      message_type: step.kind == 'template' ? 'template' : 'outgoing',
      content: conversation_message_content,
      source_id: external_id,
      additional_attributes: {
        'jrc_campaign_id' => campaign.id,
        'jrc_campaign_execution_id' => recipient.execution_id,
        'jrc_campaign_step_id' => step.id
      }
    )
    add_external_attachment(message)
    message.save!
    delivery.update!(metadata: delivery.metadata.to_h.merge('message_id' => message.id))
  end

  def conversation_message_content
    body = renderer.render(effective_value('body', step.body)).to_s
    return body if body.present?

    step.template_name.to_s
  end

  def add_external_attachment(message)
    return unless %w[image document video audio].include?(step.kind)

    file_type = { 'image' => 'image', 'video' => 'video', 'document' => 'file', 'audio' => 'file' }.fetch(step.kind)
    message.attachments.build(
      account: campaign.account,
      file_type: file_type,
      external_url: effective_value('media_url', step.media_url)
    )
  end

  def create_conversation_if_requested
    return if campaign.conversation_mode == 'reply_only'
    return if recipient.conversation_id.present?
    return unless recipient.contact

    contact_inbox = recipient.contact.contact_inboxes.find_or_create_by!(inbox: inbox) do |record|
      record.source_id = recipient.phone_number.delete_prefix('+')
    end
    conversation = recipient.contact.conversations.where(inbox_id: inbox.id).order(created_at: :desc).first
    conversation ||= Conversation.create!(
      account: campaign.account,
      inbox: inbox,
      contact: recipient.contact,
      contact_inbox: contact_inbox,
      status: campaign.conversation_mode == 'pending' ? 'pending' : 'open'
    )
    recipient.update!(conversation: conversation)
  end

  def fail_delivery(error)
    delivery = recipient.deliveries.find_or_initialize_by(step: step)
    delivery.inbox ||= inbox
    delivery.update!(status: 'failed', failed_at: Time.current, error_message: error.message)
    recipient.update!(status: 'failed', failed_at: Time.current, error_message: error.message)
    JrcCampaigns::EventLogger.call(
      campaign: campaign,
      execution: recipient.execution,
      recipient: recipient,
      event_type: 'message_failed',
      payload: { step_id: step.id, error: error.message }
    )
    JrcCampaigns::ExecutionCompletionService.new(recipient.execution).check!
  end
end
