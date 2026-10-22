# == Schema Information
#
# Table name: jrc_crm_stages
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE), not null
#  color                 :string
#  is_lost               :boolean          default(FALSE), not null
#  is_terminal           :boolean          default(FALSE), not null
#  is_won                :boolean          default(FALSE), not null
#  key                   :string           not null
#  name                  :string           not null
#  position              :integer          not null
#  probability           :decimal(5, 2)
#  requires_handoff      :boolean          default(FALSE), not null
#  settings              :jsonb            not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  legacy_sales_stage_id :bigint
#  pipeline_id           :bigint           not null
#
# Indexes
#
#  idx_jrc_crm_stages_legacy_sales              (account_id,legacy_sales_stage_id) UNIQUE WHERE (legacy_sales_stage_id IS NOT NULL)
#  index_jrc_crm_stages_on_account_id           (account_id)
#  index_jrc_crm_stages_on_pipeline_id_and_key  (pipeline_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (pipeline_id => jrc_crm_pipelines.id)
#
module JrcCrm
  class Stage < ApplicationRecord
    self.table_name = 'jrc_crm_stages'
    
    belongs_to :account
    belongs_to :pipeline, class_name: 'JrcCrm::Pipeline'
    has_many :deals
    
    validates :name, :key, :position, presence: true
    validates :position, numericality: { only_integer: true, greater_than: 0 }
    validates :probability, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
    validate do
      errors.add(:pipeline_id, 'não pode mudar enquanto a etapa possui negócios') if persisted? && will_save_change_to_pipeline_id? && deals.exists?
      errors.add(:base, 'Etapa não pode ser ganha e perdida simultaneamente') if is_won && is_lost
    end
    validates :key, uniqueness: { scope: [:account_id, :pipeline_id] }
    
    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position) }
    scope :terminal, -> { where(is_terminal: true) }
    scope :won, -> { where(is_won: true) }
    scope :lost, -> { where(is_lost: true) }
    
    before_destroy :ensure_no_deals
    validate :pipeline_belongs_to_account
    
    private
    
    def ensure_no_deals
      if deals.exists?
        errors.add(:base, 'Cannot delete stage with deals')
        throw(:abort)
      end
    end

    def pipeline_belongs_to_account
      errors.add(:pipeline, 'must belong to account') if pipeline && pipeline.account_id != account_id
    end
  end
end
