require 'digest'

class JrcCampaigns::AudienceConfirmation
  MESSAGE = 'O público selecionado diverge do público consolidado. Atualize a prévia e revise a seleção antes de aprovar ou disparar.'.freeze

  def initialize(campaign)
    @campaign = campaign
  end

  def self.for_entries(entries, channel)
    rows = entries.map { |entry| [entry.selection_key, entry.destination(channel)] }
    fingerprint(rows)
  end

  def self.fingerprint(rows)
    { 'count' => rows.size, 'digest' => Digest::SHA256.hexdigest(rows.sort.to_json) }
  end

  def valid_entries?(entries)
    confirmation.blank? || confirmation == self.class.for_entries(entries, campaign.delivery_channel)
  end

  def valid_snapshot?(entries)
    return false unless entries.is_a?(Array) && matches_selection?(entries)
    return true if confirmation.blank?

    rows = entries.map { |entry| [selection_key(entry), entry['destination']] }
    rows.any? && confirmation == self.class.fingerprint(rows)
  end

  def includes_recipient?(recipient)
    return false unless recipient.campaign_id == campaign.id && recipient.execution.campaign_id == campaign.id

    identity = recipient_identity(recipient.attributes)
    Array(campaign.review_snapshot['recipients']).any? { |entry| recipient_identity(entry) == identity }
  end

  private

  attr_reader :campaign

  def confirmation
    campaign.audience_config['selection_confirmation']
  end

  def matches_selection?(entries)
    keys = Array(campaign.audience_config['recipient_selection_keys']).to_set(&:to_s)
    include_only = campaign.audience_config['recipient_selection_mode'] == 'include'
    entries.all? { |entry| include_only == keys.include?(selection_key(entry)) }
  end

  def recipient_identity(attributes)
    attributes.slice('contact_id', 'destination', 'phone_number', 'email').merge(
      'sanitized_entry_id' => attributes['metadata'].to_h.with_indifferent_access[:sanitized_entry_id]
    )
  end

  def selection_key(entry)
    entry['contact_id'] ? "contact:#{entry['contact_id']}" : "sanitized_entry:#{entry['metadata'].to_h.with_indifferent_access[:sanitized_entry_id]}"
  end
end
