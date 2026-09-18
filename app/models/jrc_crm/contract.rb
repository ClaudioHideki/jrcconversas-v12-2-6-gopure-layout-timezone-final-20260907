# == Schema Information
#
# Table name: jrc_crm_contracts
#
#  id                  :bigint           not null, primary key
#  adjustment_index    :string           default("IPCA")
#  auto_renew          :boolean          default(FALSE), not null
#  contract_number     :string           not null
#  contract_type       :string
#  due_day             :integer
#  ends_on             :date
#  monthly_cents       :bigint           default(0), not null
#  next_adjustment_on  :date
#  notes               :text
#  one_time_cents      :bigint           default(0), not null
#  payment_condition   :string
#  renewal_notice_days :integer          default(30), not null
#  renewal_term_months :integer
#  renewal_type        :string           default("automatic")
#  starts_on           :date
#  status              :string           default("draft"), not null
#  term_months         :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  business_unit_id    :bigint
#  contact_id          :bigint
#  deal_id             :bigint           not null
#  owner_id            :bigint           not null
#  sales_order_id      :bigint           not null
#
# Indexes
#
#  idx_jrc_crm_contracts_account_number         (account_id,contract_number) UNIQUE
#  index_jrc_crm_contracts_on_account_id        (account_id)
#  index_jrc_crm_contracts_on_business_unit_id  (business_unit_id)
#  index_jrc_crm_contracts_on_contact_id        (contact_id)
#  index_jrc_crm_contracts_on_deal_id           (deal_id)
#  index_jrc_crm_contracts_on_owner_id          (owner_id)
#  index_jrc_crm_contracts_on_sales_order_id    (sales_order_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (business_unit_id => jrc_crm_business_units.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (deal_id => jrc_crm_deals.id)
#  fk_rails_...  (owner_id => users.id)
#  fk_rails_...  (sales_order_id => jrc_crm_sales_orders.id)
#
module JrcCrm
  class Contract < ApplicationRecord
    self.table_name = 'jrc_crm_contracts'
    belongs_to :account
    belongs_to :business_unit, class_name: 'JrcCrm::BusinessUnit', optional: true
    has_many :contract_items, class_name: 'JrcCrm::ContractItem', dependent: :destroy
    belongs_to :sales_order, class_name: 'JrcCrm::SalesOrder'
    belongs_to :deal, class_name: 'JrcCrm::Deal'
    belongs_to :contact, optional: true
    belongs_to :owner, class_name: 'User'
    enum status: { draft: 'draft', awaiting_signature: 'awaiting_signature', active: 'active', expiring: 'expiring', renewed: 'renewed', ended: 'ended' }
    validates :contract_number, presence: true, uniqueness: { scope: :account_id }
    before_validation :assign_number, on: :create
    def assign_number
      self.contract_number ||= "CTR-#{Time.zone.today.year}-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, '0')}"
    end
  end
end
