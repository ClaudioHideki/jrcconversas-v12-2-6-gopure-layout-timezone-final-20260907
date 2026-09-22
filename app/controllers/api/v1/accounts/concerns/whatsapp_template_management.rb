module Api::V1::Accounts::Concerns::WhatsappTemplateManagement
  extend ActiveSupport::Concern

  def whatsapp_templates
    return head :unprocessable_entity unless @inbox.whatsapp?

    management = ActiveModel::Type::Boolean.new.cast(params[:management])
    return head :forbidden if management && !template_admin?

    conversation = template_conversation
    return head :forbidden if !management && conversation.nil?

    catalog = Whatsapp::TemplateCatalogService.new(inbox: @inbox, conversation: conversation, user: Current.user)
    render json: {
      templates: catalog.templates(management: management),
      last_sync_at: @inbox.channel.message_templates_last_updated,
      last_attempt_at: catalog.settings['last_attempt_at'],
      sync_error: catalog.settings['last_error'],
      can_manage: template_admin?,
      teams: management ? Current.account.teams.select(:id, :name).as_json(only: [:id, :name]) : [],
      variable_sources: management ? Whatsapp::TemplateCatalogService::SOURCES : []
    }
  end

  def refresh_whatsapp_templates
    return head :forbidden unless template_admin?
    return head :unprocessable_entity unless @inbox.whatsapp?

    @inbox.channel.sync_templates
    render json: { success: true, last_sync_at: @inbox.channel.reload.message_templates_last_updated }
  rescue Whatsapp::TemplateSyncService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_whatsapp_template_rule
    return head :forbidden unless template_admin?
    return head :unprocessable_entity unless @inbox.whatsapp?

    attributes = params.require(:rule).permit(:enabled, :favorite, team_ids: [], bindings: {}).to_h
    catalog = Whatsapp::TemplateCatalogService.new(inbox: @inbox, user: Current.user)
    render json: { template: catalog.update_rule!(params.require(:template_key), attributes) }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def whatsapp_template_logs
    return head :forbidden unless template_admin?
    return head :unprocessable_entity unless @inbox.whatsapp?

    page = [[params[:page].to_i, 1].max, 10_000].min
    scope = @inbox.messages.where(account_id: Current.account.id, private: false)
                  .where("additional_attributes->'template_params' IS NOT NULL")
                  .includes(:conversation, :sender).reorder(created_at: :desc)
    render json: { page: page, entries: scope.limit(50).offset((page - 1) * 50).map { |message|
      {
        id: message.id, conversation_id: message.conversation.display_id, created_at: message.created_at,
        template: message.additional_attributes['template_params'],
        audit: message.additional_attributes['whatsapp_template_audit'],
        status: message.status, provider_message_id: message.source_id,
        error: message.external_error, agent_name: message.sender&.try(:name)
      }
    } }
  end

  private

  def template_admin?
    Current.user.is_a?(SuperAdmin) || Current.account_user&.administrator?
  end

  def template_conversation
    return if params[:conversation_id].blank?

    conversation = @inbox.conversations.where(account_id: Current.account.id).find_by!(display_id: params[:conversation_id])
    authorize conversation, :show? unless Current.user.is_a?(SuperAdmin)
    conversation
  end
end
