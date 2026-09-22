module JrcCrm
  class ProposalToOrderService
    def initialize(proposal:, actor:)
      @proposal, @actor = proposal, actor
    end

    def call
      raise ArgumentError, 'A proposta precisa estar aceita' unless @proposal.accepted?
      existing = @proposal.sales_orders.where.not(status: 'canceled').first
      return existing if existing

      @proposal.recalculate_totals!
      order = nil
      JrcCrm::SalesOrder.transaction do
        order = JrcCrm::SalesOrder.create!(
          account: @proposal.account, deal: @proposal.deal, proposal: @proposal,
          contact: @proposal.customer_contact, owner: @proposal.owner || @actor,
          business_unit: business_unit,
          products_cents: @proposal.initial_items_cents, shipping_cents: @proposal.shipping_cents,
          discount_cents: @proposal.total_discount_cents,
          total_cents: @proposal.total_cents.to_i + @proposal.shipping_cents.to_i,
          monthly_cents: @proposal.has_monthly_fee? ? @proposal.monthly_cents : 0,
          payment_condition: @proposal.payment_condition, payment_method: @proposal.payment_method,
          down_payment_cents: @proposal.down_payment_cents, installments_count: @proposal.installments_count,
          sold_at: Time.current,
          snapshot: JrcCrm::ProposalSerializer.new(@proposal).as_json.merge(
            'company_name' => business_unit&.name || 'GoPure',
            'origin' => 'proposal', 'proposal_number' => @proposal.proposal_number
          )
        )
        @proposal.proposal_items.find_each do |item|
          order.order_items.create!(
            product: item.product, name: item.name_snapshot, quantity: item.quantity,
            unit_cents: item.unit_price_cents, discount_cents: item.discount_cents,
            one_time_cents: item.initial_total_cents, recurring_cents: item.recurring_total_cents,
            snapshot: { description: item.description_snapshot, billing_model: item.billing_model, unit_name: item.unit_name, setup_fee_cents: item.setup_fee_cents }
          )
        end
      end
      order
    end

    private

    def business_unit
      @business_unit ||= JrcCrm::BusinessUnit.find_by(id: @proposal.business_unit_id, account_id: @proposal.account_id)
    end
  end
end
