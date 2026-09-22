# Reuses the inbox-scoped provider cache. Internal rules live in a namespaced
# provider_config key; API credentials are never returned by this service.
class Whatsapp::TemplateCatalogService
  SETTINGS_KEY = 'jrc_template_settings'.freeze
  SOURCES = %w[contact.name contact.phone_number contact.email conversation.display_id agent.name account.name team.name].freeze
  SUPPORTED_COMPONENTS = %w[HEADER BODY FOOTER BUTTONS].freeze

  def initialize(inbox:, conversation: nil, user: nil)
    @inbox, @conversation, @user = inbox, conversation, user
    @channel = inbox.channel
  end

  def templates(management: false)
    Array(@channel.message_templates).filter_map do |template|
      next unless template.is_a?(Hash)
      next unless management || allowed?(template)

      decorate(template)
    end
  end

  def find!(params)
    template = Array(@channel.message_templates).find do |item|
      item.is_a?(Hash) && item['name'] == params['name'] &&
        item['language'].to_s.casecmp?(params['language'].to_s) &&
        (params['id'].blank? || params['id'].to_s == item['id'].to_s)
    end
    raise Whatsapp::OutgoingMessageGuard::Error.new('TEMPLATE_NOT_AVAILABLE', 'O modelo selecionado não está aprovado ou disponível para esta caixa. Escolha outro modelo.') unless template && allowed?(template)

    template
  end

  def allowed?(template)
    return false unless template['status'].to_s.casecmp?('APPROVED') && supported?(template)

    rule = rule_for(template)
    return false if rule['enabled'] == false

    team_ids = Array(rule['team_ids']).map(&:to_i)
    team_ids.empty? || (@conversation && team_ids.include?(@conversation.team_id.to_i))
  end

  def supported?(template)
    components = template['components']
    return false unless components.is_a?(Array) && components.all? { |c| c.is_a?(Hash) }
    return false unless components.any? { |c| c['type'].to_s.upcase == 'BODY' }
    return false unless components.all? { |c| SUPPORTED_COMPONENTS.include?(c['type'].to_s.upcase) }

    header = components.find { |c| c['type'].to_s.upcase == 'HEADER' }
    return false if header && !%w[TEXT IMAGE VIDEO DOCUMENT].include?(header['format'].to_s.upcase)

    buttons = components.find { |c| c['type'].to_s.upcase == 'BUTTONS' }
    Array(buttons&.dig('buttons')).all? { |b| b.is_a?(Hash) && %w[URL PHONE_NUMBER QUICK_REPLY COPY_CODE].include?(b['type'].to_s.upcase) }
  end

  def key_for(template)
    "#{template['name']}|#{template['language']}"
  end

  def rule_for(template)
    settings.fetch('rules', {}).fetch(key_for(template), {})
  end

  def settings
    @settings ||= (@channel.provider_config || {}).fetch(SETTINGS_KEY, {})
  end

  def variables(template)
    Array(template['components']).flat_map do |component|
      next [] unless component.is_a?(Hash)

      type = component['type'].to_s.downcase
      if %w[body header].include?(type)
        component['text'].to_s.scan(/\{\{\s*([^{}]+?)\s*\}\}/).flatten.uniq.map { |key| "#{type}.#{key.strip}" }
      elsif type == 'buttons'
        Array(component['buttons']).each_with_index.filter_map do |button, index|
          next unless button.is_a?(Hash)

          "buttons.#{index}" if button['type'].to_s.casecmp?('COPY_CODE') || button['url'].to_s.include?('{{')
        end
      else
        []
      end
    end
  end

  def defaults_for(template)
    bindings = rule_for(template).fetch('bindings', {})
    variables(template).each_with_object({}) do |key, result|
      source = bindings[key].presence || inferred_source(key)
      value = source_value(source)
      result[key] = value.to_s if value.present?
    end
  end

  def update_rule!(key, attributes)
    template = Array(@channel.message_templates).find { |item| key_for(item) == key }
    raise ArgumentError, 'Modelo não encontrado nesta caixa.' unless template

    ids = Array(attributes['team_ids']).map(&:to_i).uniq
    raise ArgumentError, 'Equipe de outra conta ou inexistente.' unless (ids - @inbox.account.teams.where(id: ids).pluck(:id)).empty?

    bindings = attributes.fetch('bindings', {}).to_h.slice(*variables(template)).reject { |_, value| value.blank? }
    raise ArgumentError, 'Origem de variável inválida.' unless bindings.values.all? { |source| SOURCES.include?(source) }

    @channel.with_lock do
      config = (@channel.provider_config || {}).deep_dup
      data = config[SETTINGS_KEY] ||= {}
      data['rules'] ||= {}
      data['rules'][key] = {
        'enabled' => attributes['enabled'] != false,
        'favorite' => attributes['favorite'] == true,
        'team_ids' => ids, 'bindings' => bindings,
        'updated_by' => @user&.id, 'updated_at' => Time.current.iso8601
      }
      # Avoid credential validation / remote calls for internal access rules.
      @channel.update_columns(provider_config: config, updated_at: Time.current)
    end
    @settings = nil
    @inbox.update_account_cache
    Rails.logger.info("[WHATSAPP_TEMPLATE_RULE] account_id=#{@inbox.account_id} inbox_id=#{@inbox.id} actor_id=#{@user&.id} template_id=#{template['id']}")
    decorate(template)
  end

  private

  def decorate(template)
    template.deep_dup.merge('jrc' => {
      'key' => key_for(template), 'supported' => supported?(template),
      'enabled' => rule_for(template)['enabled'] != false,
      'favorite' => rule_for(template)['favorite'] == true,
      'team_ids' => Array(rule_for(template)['team_ids']),
      'bindings' => rule_for(template).fetch('bindings', {}),
      'variables' => variables(template), 'defaults' => defaults_for(template)
    })
  end

  def inferred_source(key)
    name = key.split('.').last.to_s.downcase
    return 'contact.name' if %w[nome name contact_name nome_cliente cliente].include?(name)
    return 'conversation.display_id' if %w[protocolo protocol ticket_id].include?(name)
    return 'agent.name' if %w[agent_name nome_agente atendente].include?(name)
    return 'account.name' if %w[company_name empresa].include?(name)

    nil # Never guess what a positional {{1}} means.
  end

  def source_value(source)
    case source
    when 'contact.name' then @conversation&.contact&.name
    when 'contact.phone_number' then @conversation&.contact&.phone_number
    when 'contact.email' then @conversation&.contact&.email
    when 'conversation.display_id' then @conversation && "##{@conversation.display_id}"
    when 'agent.name' then @user&.name
    when 'account.name' then @inbox.account.name
    when 'team.name' then @conversation&.team&.name
    end
  end
end
