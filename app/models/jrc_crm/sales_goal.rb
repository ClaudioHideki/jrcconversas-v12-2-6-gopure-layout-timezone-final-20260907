# == Schema Information
#
# Table name: jrc_crm_sales_goals
#
#  id                 :bigint           not null, primary key
#  allocations        :jsonb            not null
#  calculation_method :string           default("approved_orders"), not null
#  currency           :string           default("BRL"), not null
#  description        :text
#  indicators         :jsonb            not null
#  metric             :string           default("revenue"), not null
#  name               :string
#  period_end         :date             not null
#  period_kind        :string           default("monthly"), not null
#  period_start       :date             not null
#  product_targets    :jsonb            not null
#  published_at       :datetime
#  scope_kind         :string           default("user"), not null
#  settings           :jsonb            not null
#  status             :string           default("draft"), not null
#  target_cents       :bigint           default(0), not null
#  target_quantity    :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  business_unit_id   :bigint
#  product_id         :bigint
#  team_id            :bigint
#  user_id            :bigint
#
# Indexes
#
#  idx_jrc_crm_goals_period                            (account_id,user_id,period_start,period_end) UNIQUE
#  index_jrc_crm_sales_goals_on_account_id             (account_id)
#  index_jrc_crm_sales_goals_on_account_id_and_status  (account_id,status)
#  index_jrc_crm_sales_goals_on_business_unit_id       (business_unit_id)
#  index_jrc_crm_sales_goals_on_product_id             (product_id)
#  index_jrc_crm_sales_goals_on_team_id                (team_id)
#  index_jrc_crm_sales_goals_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (business_unit_id => jrc_crm_business_units.id)
#  fk_rails_...  (product_id => jrc_crm_products.id)
#  fk_rails_...  (user_id => users.id)
#
module JrcCrm
  class SalesGoal < ApplicationRecord
    self.table_name = 'jrc_crm_sales_goals'
    belongs_to :account
    belongs_to :business_unit, class_name: 'JrcCrm::BusinessUnit', optional: true
    belongs_to :product, class_name: 'JrcCrm::Product', optional: true
    belongs_to :user, optional: true
    belongs_to :team, optional: true

    validates :scope_kind, inclusion: { in: %w[user team business_unit product company] }
    validates :metric, inclusion: { in: %w[revenue quantity mrr customers renewals conversion ticket] }
    validates :status, inclusion: { in: %w[draft active archived] }
    validates :period_start, :period_end, presence: true
    validates :target_cents, numericality: { greater_than_or_equal_to: 0 }
    validate { errors.add(:period_end, 'must be after period start') if period_start && period_end && period_end < period_start }
    validate { errors.add(:user, 'must belong to account') if user && !account.users.exists?(user.id) }
    validate { errors.add(:team, 'must belong to account') if team && team.account_id != account_id }
    validate :published_distribution_matches_target
    validate :published_products_match_target

    def published_distribution_matches_target
      return unless status == 'active' && allocations.present? && %w[revenue mrr ticket].include?(metric)
      allocated = Array(allocations).sum { |row| (row['target_cents'] || row[:target_cents]).to_i }
      errors.add(:allocations, 'must equal the goal total before publication') if allocated != target_cents.to_i
    end

    def published_products_match_target
      return unless status == 'active' && product_targets.present? && %w[revenue mrr ticket].include?(metric)
      distributed = Array(product_targets).sum { |row| (row['target_cents'] || row[:target_cents]).to_i }
      errors.add(:product_targets, 'must equal the goal total before publication') if distributed != target_cents.to_i
    end

    before_validation do
      self.name = name.to_s.strip.presence || "Meta #{period_start&.strftime('%m/%Y')}"
      self.allocations ||= []
      self.product_targets ||= []
      self.indicators ||= []
      self.settings ||= {}
    end
  end
end
