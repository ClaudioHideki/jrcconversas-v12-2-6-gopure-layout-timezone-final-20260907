require 'cgi'

class JrcCrm::HistoricalProposalLink
  PURPOSE = 'jrc-crm-historical-document'.freeze
  LIFETIME = 7.days

  def self.token(proposal)
    Rails.application.message_verifier(PURPOSE).generate(
      { 'account_id' => proposal.account_id, 'proposal_id' => proposal.id }, purpose: PURPOSE, expires_in: LIFETIME
    )
  end

  def self.verify(token)
    Rails.application.message_verifier(PURPOSE).verified(token, purpose: PURPOSE)
  end

  def self.url(proposal, base_url:)
    "#{base_url.to_s.sub(%r{/$}, '')}/jrc/propostas-historicas/#{proposal.account_id}/#{CGI.escape(token(proposal))}"
  end

  def self.validate_url!(url, proposal:, base_url:)
    # The full origin and exact read-only route are required, not a hostname substring.
    prefix = "#{base_url.to_s.sub(%r{/$}, '')}/jrc/propostas-historicas/#{proposal.account_id}/"
    raise ArgumentError, 'Link de consulta inválido.' unless url.is_a?(String) && url.start_with?(prefix)

    data = verify(CGI.unescape(url.delete_prefix(prefix)))
    raise ArgumentError, 'Link de consulta inválido ou expirado.' unless data == { 'account_id' => proposal.account_id, 'proposal_id' => proposal.id }

    url
  end
end
