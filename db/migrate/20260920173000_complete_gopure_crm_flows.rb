class CompleteGopureCrmFlows < ActiveRecord::Migration[7.1]
  def change
    change_table :jrc_crm_contracts, bulk: true do |t|
      t.string :signature_status, null: false, default: 'not_started' unless column_exists?(:jrc_crm_contracts, :signature_status)
      t.string :signature_mode unless column_exists?(:jrc_crm_contracts, :signature_mode)
      t.string :signature_provider unless column_exists?(:jrc_crm_contracts, :signature_provider)
      t.string :signature_external_id unless column_exists?(:jrc_crm_contracts, :signature_external_id)
      t.string :signed_by_name unless column_exists?(:jrc_crm_contracts, :signed_by_name)
      t.datetime :signed_at unless column_exists?(:jrc_crm_contracts, :signed_at)
      t.jsonb :lifecycle_metadata, null: false, default: {} unless column_exists?(:jrc_crm_contracts, :lifecycle_metadata)
      t.text :content_override unless column_exists?(:jrc_crm_contracts, :content_override)
    end

    unless column_exists?(:jrc_crm_contracts, :source_contract_id)
      add_reference :jrc_crm_contracts, :source_contract, foreign_key: { to_table: :jrc_crm_contracts }, index: true
    end

    change_table :jrc_crm_sales_commissions, bulk: true do |t|
      t.jsonb :calculation, null: false, default: {} unless column_exists?(:jrc_crm_sales_commissions, :calculation)
      t.decimal :goal_attainment_percent, precision: 8, scale: 3 unless column_exists?(:jrc_crm_sales_commissions, :goal_attainment_percent)
      t.decimal :share_percent, precision: 8, scale: 3, null: false, default: 100 unless column_exists?(:jrc_crm_sales_commissions, :share_percent)
      t.string :event_key unless column_exists?(:jrc_crm_sales_commissions, :event_key)
      t.datetime :accrued_at unless column_exists?(:jrc_crm_sales_commissions, :accrued_at)
    end

    add_index :jrc_crm_sales_commissions, :event_key unless index_exists?(:jrc_crm_sales_commissions, :event_key)
  end
end
