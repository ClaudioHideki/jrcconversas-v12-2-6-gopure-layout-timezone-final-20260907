# Commercial defaults apply to new documents only. Never rewrite issued terms.
class JrcCrm::ProposalProfile
  CONFIG = Rails.application.config_for(:jrc_crm_proposal_profiles).to_h.deep_stringify_keys.freeze

  def self.gopure?(account, unit: nil)
    profile = account.custom_attributes.to_h['jrc_crm_proposal_profile']
    configured = profile == 'gopure' || (profile.blank? && CONFIG.fetch('gopure').fetch('account_names').include?(account.name.to_s.downcase.delete(' ')))
    return false unless configured

    company = unit&.operating_company
    company.nil? || company.tax_id.to_s.gsub(/\D/, '') == CONFIG.fetch('gopure').fetch('issuer_tax_id').gsub(/\D/, '')
  end

  def self.defaults(account, unit: nil)
    return {} unless gopure?(account, unit: unit)

    CONFIG.fetch('gopure').slice('issuer_company_name', 'issuer_tax_id').symbolize_keys.merge(
      commercial_notes: '', monthly_cents: 0, renewal_type: 'none', cancellation_penalty_percent: 0,
      approval_status: 'pending', commercial_approval_status: 'pending',
      financial_approval_status: 'not_required', technical_approval_status: 'not_required'
    )
  end

  def self.commercial_only?(proposal)
    if proposal.events.loaded?
      return proposal.events.any? { |event| %w[created duplicated].include?(event.event_type) && event.metadata['commercial_profile'] == 'gopure_v1' }
    end
    proposal.events.where(event_type: %w[created duplicated]).where("metadata ->> 'commercial_profile' = ?", 'gopure_v1').exists?
  end
end
