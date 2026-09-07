class JrcCampaigns::Event < ApplicationRecord
  self.table_name = 'jrc_campaign_events'

  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  belongs_to :execution, class_name: 'JrcCampaigns::Execution', optional: true
  belongs_to :recipient, class_name: 'JrcCampaigns::Recipient', optional: true

  validates :event_type, :occurred_at, presence: true
end
