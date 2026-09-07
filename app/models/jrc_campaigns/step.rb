class JrcCampaigns::Step < ApplicationRecord
  self.table_name = 'jrc_campaign_steps'

  KINDS = %w[text template image document video audio email].freeze

  belongs_to :campaign, class_name: 'JrcCampaigns::Campaign'
  belongs_to :media_asset, class_name: 'JrcCampaigns::MediaAsset', optional: true
  has_many :deliveries, class_name: 'JrcCampaigns::Delivery', dependent: :destroy

  validates :kind, inclusion: { in: KINDS }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :delay_after_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :follow_up_after_hours, numericality: { greater_than: 0 }, allow_nil: true
  validates :body, presence: true, if: -> { kind == 'text' }
  validates :template_name, :template_language, presence: true, if: -> { kind == 'template' }
  validates :media_url, presence: true, if: -> { %w[image document video audio].include?(kind) }
  validates :subject, :body, presence: true, if: -> { kind == 'email' }
  validate :kind_matches_delivery_channel
  validate :media_asset_belongs_to_campaign_account

  private

  def kind_matches_delivery_channel
    return unless campaign
    return if campaign.email? && kind == 'email'
    return if campaign.whatsapp? && kind != 'email'

    errors.add(:kind, 'não corresponde ao canal de envio da campanha')
  end

  def media_asset_belongs_to_campaign_account
    return unless media_asset && campaign
    return if media_asset.account_id == campaign.account_id

    errors.add(:media_asset, 'deve pertencer à mesma conta da campanha')
  end
end
