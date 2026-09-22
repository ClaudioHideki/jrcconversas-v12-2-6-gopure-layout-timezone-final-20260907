class Whatsapp::TemplateSyncService
  class Error < StandardError; end

  def initialize(channel)
    @channel = channel
  end

  def call
    # Fetch all pages BEFORE replacing the cache. A failed page must not expose
    # a partial catalog or leave a removed template approved locally forever.
    templates = @channel.provider_service.load_templates!
    raise Error, 'Resposta inválida do provedor.' unless templates.is_a?(Array) && templates.all? { |item| item.is_a?(Hash) && item['name'].present? }

    persist_sync(templates: templates)
    @channel.inbox&.update_account_cache
    templates
  rescue StandardError => e
    persist_sync(error: 'Não foi possível sincronizar. Verifique as credenciais e a disponibilidade do provedor.')
    # Do not log token-bearing URLs or provider credentials.
    Rails.logger.warn("[WHATSAPP_TEMPLATE_SYNC] account_id=#{@channel.account_id} channel_id=#{@channel.id} error_class=#{e.class}")
    raise Error, 'Não foi possível sincronizar os modelos. O catálogo anterior foi preservado; verifique a conexão da caixa.'
  end

  private

  def persist_sync(templates: nil, error: nil)
    @channel.with_lock do
      config = (@channel.provider_config || {}).deep_dup
      settings = config[Whatsapp::TemplateCatalogService::SETTINGS_KEY] ||= {}
      settings['last_attempt_at'] = Time.current.utc.iso8601
      settings['last_error'] = error
      columns = { provider_config: config, updated_at: Time.current }
      unless error
        settings['last_success_at'] = Time.current.iso8601
        columns.merge!(message_templates: templates, message_templates_last_updated: Time.current)
      end
      @channel.update_columns(columns)
    end
  end
end
