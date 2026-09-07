class JrcCampaigns::CampaignInbox < ApplicationRecord
  self.table_name = 'jrc_campaign_inboxes'

  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  belongs_to :inbox

  validates :inbox_id, uniqueness: { scope: :campaign_id }
  validates :weight, numericality: { greater_than: 0 }
  validate :inbox_belongs_to_campaign_account
  validate :channel_matches_campaign

  private

  def inbox_belongs_to_campaign_account
    errors.add(:inbox, 'deve pertencer à mesma conta') if inbox && inbox.account_id != campaign.account_id
  end

  def channel_matches_campaign
    return unless inbox && campaign
    return if inbox.channel_type == campaign.expected_channel_type

    channel_name = campaign.email? ? 'E-mail' : 'WhatsApp'
    errors.add(:inbox, "deve ser uma caixa de #{channel_name}")
  end
end
