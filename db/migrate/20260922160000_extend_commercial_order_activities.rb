class ExtendCommercialOrderActivities < ActiveRecord::Migration[7.1]
  def up
    add_reference :jrc_crm_activities, :sales_order, foreign_key: { to_table: :jrc_crm_sales_orders }, index: true
    change_column_default :jrc_crm_products, :contract_term_months, from: 12, to: nil
    change_column_null :jrc_crm_products, :contract_term_months, true
  end

  def down
    linked_activities = select_value('SELECT COUNT(*) FROM jrc_crm_activities WHERE sales_order_id IS NOT NULL').to_i
    unknown_terms = select_value('SELECT COUNT(*) FROM jrc_crm_products WHERE contract_term_months IS NULL').to_i
    if linked_activities.positive? || unknown_terms.positive?
      raise ActiveRecord::IrreversibleMigration, 'Rollback would discard order activity links or invent contract terms. Preserve data and use a forward migration.'
    end

    change_column_null :jrc_crm_products, :contract_term_months, false
    change_column_default :jrc_crm_products, :contract_term_months, from: nil, to: 12
    remove_reference :jrc_crm_activities, :sales_order, foreign_key: { to_table: :jrc_crm_sales_orders }, index: true
  end
end
