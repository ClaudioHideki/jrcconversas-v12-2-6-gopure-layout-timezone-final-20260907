class JrcCampaigns::Recipient < ApplicationRecord
  self.table_name = 'jrc_campaign_recipients'

  STATUSES = %w[queued processing sent delivered read replied failed skipped canceled].freeze

  enum :status, STATUSES.index_with(&:itself)


  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  belongs_to :execution, class_name: 'JrcCampaigns::Execution'
  belongs_to :contact, optional: true
  belongs_to :inbox, optional: true
  belongs_to :conversation, optional: true
  has_many :deliveries, class_name: 'JrcCampaigns::Delivery', dependent: :destroy
  has_many :events, class_name: 'JrcCampaigns::Event', dependent: :destroy

  validates :phone_number, presence: true, if: -> { campaign&.whatsapp? }
  validates :email, presence: true, if: -> { campaign&.email? }
  validates :destination, presence: true
  validates :status, inclusion: { in: STATUSES }
end
