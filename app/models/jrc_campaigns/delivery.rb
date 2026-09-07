class JrcCampaigns::Delivery < ApplicationRecord
  self.table_name = 'jrc_campaign_deliveries'

  STATUSES = %w[queued sent delivered read failed].freeze

  enum :status, STATUSES.index_with(&:itself)


  belongs_to :recipient, class_name: 'JrcCampaigns::Recipient'
  belongs_to :step, class_name: 'JrcCampaigns::Step'
  belongs_to :inbox

  validates :status, inclusion: { in: STATUSES }
  validates :step_id, uniqueness: { scope: :recipient_id }
end
