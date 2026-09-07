class JrcCampaigns::SanitizedList < ApplicationRecord
  self.table_name = 'jrc_campaign_sanitized_lists'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :entries, class_name: 'JrcCampaigns::SanitizedEntry', dependent: :destroy

  validates :name, presence: true
end
