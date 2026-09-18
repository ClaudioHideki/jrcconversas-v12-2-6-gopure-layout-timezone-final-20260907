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
      JrcCrm::SalesOrder.create!(
        account: @proposal.account, deal: @proposal.deal, proposal: @proposal,
        contact: @proposal.customer_contact, owner: @proposal.owner || @actor,
        products_cents: @proposal.initial_items_cents, shipping_cents: @proposal.shipping_cents,
        discount_cents: @proposal.total_discount_cents,
        total_cents: @proposal.total_cents.to_i + @proposal.shipping_cents.to_i,
        monthly_cents: @proposal.has_monthly_fee? ? @proposal.monthly_cents : 0,
        payment_condition: @proposal.payment_condition, payment_method: @proposal.payment_method,
        down_payment_cents: @proposal.down_payment_cents, installments_count: @proposal.installments_count,
        sold_at: Time.current, snapshot: JrcCrm::ProposalSerializer.new(@proposal).as_json
      )
    end
  end
end
