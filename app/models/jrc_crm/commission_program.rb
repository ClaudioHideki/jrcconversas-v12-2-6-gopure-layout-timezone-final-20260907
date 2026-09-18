# == Schema Information
#
# Table name: jrc_crm_commission_programs
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  ends_on           :date
#  name              :string           not null
#  release_condition :string           default("order_approved"), not null
#  rules             :jsonb            not null
#  starts_on         :date
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  business_unit_id  :bigint
#
# Indexes
#
#  index_jrc_crm_commission_programs_on_account_id        (account_id)
#  index_jrc_crm_commission_programs_on_business_unit_id  (business_unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (business_unit_id => jrc_crm_business_units.id)
#
module JrcCrm
  class CommissionProgram < ApplicationRecord
    self.table_name = 'jrc_crm_commission_programs'
    belongs_to :account
    belongs_to :business_unit, class_name: 'JrcCrm::BusinessUnit', optional: true
    has_many :sales_commissions, class_name: 'JrcCrm::SalesCommission', dependent: :restrict_with_error
    validates :name, :release_condition, presence: true
  end
end
