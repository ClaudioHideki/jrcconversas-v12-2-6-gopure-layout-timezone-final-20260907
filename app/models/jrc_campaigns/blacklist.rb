class JrcCampaigns::Blacklist < ApplicationRecord
  self.table_name = 'jrc_campaign_blacklists'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  validates :phone_number, presence: true, uniqueness: { scope: :account_id }
  before_validation :normalize_phone_number

  private

  def normalize_phone_number
    self.phone_number = JrcCampaigns::PhoneNormalizer.call(phone_number)
  end
end
