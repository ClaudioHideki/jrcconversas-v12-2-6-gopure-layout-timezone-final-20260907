class JrcCampaigns::EvolutionClient
  class Rejected < StandardError; end
  class UnknownResult < StandardError; end

  def initialize(connector)
    @connector = connector
  end

  # A read-only preflight binds the configured sender to the connected instance.
  def verify_sender!
    instances = request(:get, "/instance/fetchInstances?instanceName=#{connector.instance}")
    instance = Array(instances).find { |item| item['name'] == connector.instance }
    unless instance && instance['connectionStatus'] == 'open' &&
           instance['ownerJid'].to_s.split('@').first.to_s.split(':').first == connector.sender_number
      raise Rejected, 'Instância Evolution desconectada ou número remetente diferente do configurado.'
    end
  end

  def send_message(phone_number:, kind:, body:, media_url: nil, file_name: nil)
    raise Rejected, 'Mensagem de texto vazia.' if kind == 'text' && body.blank?
    if kind.in?(%w[image document video audio])
      uri = URI.parse(media_url.to_s)
      raise Rejected, 'A mídia Evolution exige uma URL HTTPS válida.' unless uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil?
    end
    number = phone_number.delete_prefix('+')
    path, payload = case kind
                    when 'text'
                      ['/message/sendText', { number: number, text: body, linkPreview: false }]
                    when 'image', 'document', 'video'
                      ['/message/sendMedia', { number: number, mediatype: kind, media: media_url, caption: body, fileName: file_name }]
                    when 'audio'
                      ['/message/sendWhatsAppAudio', { number: number, audio: media_url }]
                    else
                      raise Rejected, 'Tipo de mensagem não suportado pela Evolution; templates Meta exigem caixa oficial.'
                    end
    response = request(:post, "#{path}/#{connector.instance}", payload)
    key = response.is_a?(Hash) ? response['key'] : nil
    unless key.is_a?(Hash) && key['id'].present? && key['fromMe'] == true &&
           [key['remoteJid'], key['remoteJidAlt']].include?("#{number}@s.whatsapp.net")
      raise UnknownResult, 'Evolution não retornou um identificador confirmado para o destinatário; reenvio bloqueado.'
    end

    key.fetch('id')
  rescue URI::InvalidURIError
    raise Rejected, 'URL de mídia inválida.'
  end

  def status(external_id)
    response = request(:post, "/chat/findMessages/#{connector.instance}", { where: { key: { id: external_id, fromMe: true } }, offset: 1, page: 1 })
    records = response.dig('messages', 'records')
    record = Array(records).find { |item| item.dig('key', 'id') == external_id && item.dig('key', 'fromMe') == true }
    statuses = Array(record&.fetch('MessageUpdate', nil)).map { |item| item['status'] }
    return 'read' if (statuses & %w[READ PLAYED]).any?
    return 'delivered' if statuses.include?('DELIVERY_ACK')
    return 'failed' if statuses.include?('ERROR')

    'sent' if statuses.include?('SERVER_ACK')
  end

  private

  attr_reader :connector

  def request(method, path, payload = nil)
    SafeFetch.fetch(
      "#{connector.base_url}#{path}", method: method, body: payload&.to_json,
      headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'apikey' => connector.api_key },
      sensitive_headers: ['apikey'], allowed_content_types: ['application/json'], max_bytes: 1.megabyte,
      open_timeout: 5, read_timeout: 20
    ) { |result| JSON.parse(result.tempfile.read) }
  rescue SafeFetch::HttpError => e
    code = e.message.to_s[/\A\d{3}/].to_i
    raise Rejected, "Evolution recusou a solicitação (HTTP #{code})." if [400, 401, 403, 404, 422, 429].include?(code)

    raise UnknownResult, "Resultado Evolution desconhecido (HTTP #{code}); reenvio bloqueado."
  rescue SafeFetch::Error, JSON::ParserError, Timeout::Error
    # Never retain response bodies, credentials or URLs from provider exceptions.
    raise UnknownResult, 'Sem confirmação válida da Evolution; reenvio automático bloqueado.'
  end
end
