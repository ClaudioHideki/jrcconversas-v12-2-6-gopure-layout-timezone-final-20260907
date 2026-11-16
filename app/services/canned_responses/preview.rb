require 'digest'

# Resolves only the selected, authorized conversation. Uses the same Liquid drops as Message.
class CannedResponses::Preview
  class Invalid < StandardError; end

  def initialize(response:, conversation:, user:)
    @response = response
    @conversation = conversation
    @user = user
    raise ActiveRecord::RecordNotFound unless response.account_id == conversation.account_id
  end

  def self.context_for(conversation)
    Digest::SHA256.hexdigest([
      conversation.account_id, conversation.id, conversation.contact_id,
      conversation.contact_inbox_id, conversation.inbox_id
    ].to_json)
  end

  def call
    raise Invalid, 'INVALID_CONTENT' if @response.content.bytesize > 65_536

    message = @conversation.messages.build(sender: @user, inbox: @conversation.inbox, account: @conversation.account)
    text = render_liquid(message)
    text = expand_aliases(text, alias_values)
    { content: text, unresolved: text.scan(/\[[^\]\n]+\]|\{\{[^}]+\}\}/).uniq }
  end

  private

  def alias_values
    contact = @conversation.contact
    attributes = contact.additional_attributes || {}
    {
      'nome' => contact.name, 'vendedor' => @user.name, 'empresa' => company_name(contact),
      'cidade' => attributes['city'], 'região' => attributes['region'],
      'data' => Time.current.in_time_zone(@conversation.account.reporting_timezone.presence || Time.zone).strftime('%d/%m/%Y'),
      'produto/serviço' => @conversation.custom_attributes&.[]('produto_servico')
    }
  end

  def render_liquid(message)
    template = Liquid::Template.parse(@response.content)
    template.resource_limits.render_length_limit = 65_536
    template.resource_limits.render_score_limit = 10_000
    template.resource_limits.assign_score_limit = 10_000
    template.render!(message.send(:message_drops), strict_variables: true)
  rescue Liquid::MemoryError
    raise Invalid, 'RENDER_LIMIT'
  rescue Liquid::Error
    # Preserve missing native variables for manual correction.
    @response.content
  end

  def expand_aliases(text, aliases)
    resolved_bytes = text.bytesize
    text.gsub(%r{\[(nome|vendedor|empresa|cidade|região|data|produto/serviço)\]}) do |token|
      value = aliases[Regexp.last_match(1)]
      next token unless value.is_a?(String) && value.present?

      resolved_bytes += value.bytesize - token.bytesize
      raise Invalid, 'RENDER_LIMIT' if resolved_bytes > 65_536

      value
    end
  end

  def company_name(contact)
    return unless contact.company_id

    context = { user: @user, account: @conversation.account,
                account_user: @conversation.account.account_users.find_by(user_id: @user.id) }
    return unless JrcCustomers::DirectoryPolicy.new(context, :directory).access?

    JrcCrm::CorporateCoverage.new(account: @conversation.account, user: @user)
                             .companies(@conversation.account.master_companies).find_by(id: contact.company_id)&.name
  end
end
