class JrcCampaigns::SanitizedEntry < ApplicationRecord
  self.table_name = 'jrc_campaign_sanitized_entries'

  STATUSES = %w[valid invalid duplicate blacklisted].freeze

  belongs_to :sanitized_list, class_name: 'JrcCampaigns::SanitizedList'

  validates :status, inclusion: { in: STATUSES }
end
