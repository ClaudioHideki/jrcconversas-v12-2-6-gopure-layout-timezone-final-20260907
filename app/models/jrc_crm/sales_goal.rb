# == Schema Information
#
# Table name: jrc_crm_sales_goals
#
#  id               :bigint           not null, primary key
#  metric           :string           default("revenue"), not null
#  period_end       :date             not null
#  period_start     :date             not null
#  scope_kind       :string           default("user"), not null
#  target_cents     :bigint           default(0), not null
#  target_quantity  :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  business_unit_id :bigint
#  product_id       :bigint
#  user_id          :bigint
#
# Indexes
#
#  idx_jrc_crm_goals_period                       (account_id,user_id,period_start,period_end) UNIQUE
#  index_jrc_crm_sales_goals_on_account_id        (account_id)
#  index_jrc_crm_sales_goals_on_business_unit_id  (business_unit_id)
#  index_jrc_crm_sales_goals_on_product_id        (product_id)
#  index_jrc_crm_sales_goals_on_user_id           (user_id)
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
    validates :scope_kind, inclusion: { in: %w[user team business_unit product] }
    validates :metric, inclusion: { in: %w[revenue quantity mrr] }
    validates :period_start, :period_end, presence: true
    validate { errors.add(:period_end, 'must be after period start') if period_start && period_end && period_end < period_start }
    validate { errors.add(:user, 'must belong to account') if user && !account.users.exists?(user.id) }
  end
end
