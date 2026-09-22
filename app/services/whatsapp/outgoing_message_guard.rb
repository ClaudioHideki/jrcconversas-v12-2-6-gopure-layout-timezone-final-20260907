require 'digest'
require 'uri'

class Whatsapp::OutgoingMessageGuard
  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  def initialize(conversation, user: nil)
    @conversation, @user = conversation, user
  end

  def call(template_params: nil, private_note: false, message_type: 'outgoing')
    return unless @conversation.inbox.channel_type == 'Channel::Whatsapp'
    return if ActiveModel::Type::Boolean.new.cast(private_note)
    return unless %w[outgoing template].include?(message_type.to_s)

    if template_params.blank?
      unless Whatsapp::ConversationWindowService.new(@conversation).can_send_free_message?
        raise Error.new('WHATSAPP_WINDOW_CLOSED', 'A janela do WhatsApp está encerrada. Escolha um modelo aprovado e aguarde a resposta do cliente.')
      end
      return
    end

    raw = template_params.respond_to?(:to_unsafe_h) ? template_params.to_unsafe_h : template_params
    raise Error.new('INVALID_TEMPLATE_PARAMETERS', 'Os dados do modelo são inválidos.') unless raw.is_a?(Hash)

    raw = raw.deep_stringify_keys
    catalog = Whatsapp::TemplateCatalogService.new(inbox: @conversation.inbox, conversation: @conversation, user: @user)
    template = catalog.find!(raw)
    normalized = Whatsapp::TemplateParameterConverterService.new(raw.deep_dup, template).normalize_to_enhanced
    parameters = validate_parameters!(template, normalized['processed_params'] || {})
    canonical = {
      'name' => template['name'], 'language' => template['language'],
      'category' => template['category'], 'processed_params' => parameters
    }
    canonical['namespace'] = template['namespace'] if template['namespace'].present?
    {
      template_params: canonical,
      content: render_body(template, parameters),
      audit: {
        'template_id' => template['id'], 'template_name' => template['name'],
        'template_version' => Digest::SHA256.hexdigest(template.fetch('components', []).to_json),
        'language' => template['language'], 'category' => template['category'],
        'account_id' => @conversation.account_id, 'inbox_id' => @conversation.inbox_id,
        'contact_id' => @conversation.contact_id, 'conversation_id' => @conversation.display_id,
        'agent_id' => @user&.id, 'team_id' => @conversation.team_id,
        'provider' => @conversation.inbox.channel.provider,
        'queued_at' => Time.current.iso8601
      }
    }
  rescue ArgumentError => e
    raise Error.new('INVALID_TEMPLATE_PARAMETERS', "Revise as variáveis do modelo: #{e.message}")
  end

  private

  def variable_keys(text)
    keys = text.to_s.scan(/\{\{\s*([^{}]+?)\s*\}\}/).flatten.map(&:strip).uniq
    keys.all? { |key| key.match?(/\A[0-9]+\z/) } ? keys.sort_by(&:to_i) : keys
  end

  def validate_parameters!(template, params)
    raise ArgumentError, 'Formato de variáveis inválido.' unless params.is_a?(Hash)

    result = {}
    Array(template['components']).each do |component|
      type = component['type'].to_s.downcase
      if %w[body header].include?(type)
        if type == 'header' && %w[IMAGE VIDEO DOCUMENT].include?(component['format'].to_s.upcase)
          result['header'] = media_header!(component, params['header'])
        else
          keys = variable_keys(component['text'])
          values = params[type].is_a?(Hash) ? params[type] : {}
          result[type] = keys.to_h { |key| [key, required_text!(values[key], "#{type}.#{key}")] } if keys.any?
        end
      elsif type == 'buttons'
        result['buttons'] = buttons!(component, params['buttons'])
      end
    end
    result
  end

  def required_text!(value, key)
    if value.is_a?(Hash) && %w[currency date_time].include?(value['type'])
      raise ArgumentError, "Preencha #{key}." if value['fallback_value'].blank?
      return value
    end
    raise ArgumentError, "Preencha #{key}." unless value.is_a?(String) || value.is_a?(Numeric)
    text = value.to_s.strip
    raise ArgumentError, "Preencha #{key}." if text.empty?
    raise ArgumentError, "#{key} excede 1.000 caracteres." if text.length > 1000
    raise ArgumentError, "Remova quebras de linha de #{key}." if text.match?(/[\r\n\t]/)

    text
  end

  def media_header!(component, header)
    raise ArgumentError, 'Informe a URL da mídia do cabeçalho.' unless header.is_a?(Hash)

    url = header['media_url'].to_s.strip
    uri = URI.parse(url)
    unless %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil? && url.length <= 2000
      raise ArgumentError, 'Informe uma URL HTTP ou HTTPS válida para a mídia.'
    end
    { 'media_type' => component['format'].downcase, 'media_url' => url,
      'media_name' => header['media_name'].to_s.first(255) }.compact
  rescue URI::InvalidURIError
    raise ArgumentError, 'URL da mídia inválida.'
  end

  def buttons!(component, values)
    values = [] unless values.is_a?(Array)
    Array(component['buttons']).each_with_index.map do |button, index|
      type = button['type'].to_s.downcase
      entry = { 'type' => type }
      if type == 'copy_code' || (type == 'url' && variable_keys(button['url']).any?)
        value = required_text!(values[index].is_a?(Hash) ? values[index]['parameter'] : nil, "buttons.#{index}")
        raise ArgumentError, 'O cupom pode ter até 15 caracteres.' if type == 'copy_code' && value.length > 15
        entry['parameter'] = value
      end
      entry
    end
  end

  def render_body(template, params)
    body = Array(template['components']).find { |c| c['type'].to_s.casecmp?('BODY') }&.dig('text').to_s
    body.gsub(/\{\{\s*([^{}]+?)\s*\}\}/) do
      value = params.fetch('body', {})[Regexp.last_match(1).strip]
      value.is_a?(Hash) ? value['fallback_value'].to_s : value.to_s
    end
  end
end
