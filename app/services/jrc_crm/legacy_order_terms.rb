# GoPure r5 persisted initial fees separately from recurring charges. Reading
# those orders through the Lab calculator would change their displayed price.
# Keep the saved amounts/plan; new orders carry snapshot['financials'] instead.
class JrcCrm::LegacyOrderTerms
  def self.applicable?(order)
    order.snapshot.to_h['financial_version'] == 2 && !order.snapshot.to_h.key?('financials')
  end

  def initialize(order)
    @order = order
    @snapshot = order.snapshot.to_h.deep_symbolize_keys
    @items = order.order_items.order(:id).map { |item| item.attributes.deep_symbolize_keys }
    @installments = Array(@snapshot[:installments]).map(&:deep_symbolize_keys)
    @first_due_date = @snapshot[:first_due_date] || @installments.first&.dig(:date)
  end

  def call
    initial_terms.merge(recurring_terms).merge(payment_terms).merge(
      legacy_gopure_terms: true, financial_version: 2, items: @items
    )
  end

  private

  def initial_terms
    {
      products_cents: @order.products_cents.to_i, subtotal_cents: @order.products_cents.to_i,
      item_discount_cents: @items.sum { |item| item[:discount_cents].to_i },
      discount_cents: @order.discount_cents.to_i, total_cents: @order.total_cents.to_i,
      shipping_cents: @order.shipping_cents.to_i,
      shipping_mode: @snapshot[:shipping_mode] || (@order.shipping_cents.to_i.positive? ? 'separate' : 'not_applicable'),
      shipping_in_installments: @snapshot.fetch(:shipping_in_installments, true),
      taxes_cents: @snapshot[:taxes_cents].to_i, surcharge_cents: @snapshot[:surcharge_cents].to_i
    }
  end

  def recurring_terms
    {
      monthly_cents: @order.monthly_cents.to_i,
      has_monthly_fee: @snapshot.fetch(:has_monthly_fee, @order.monthly_cents.to_i.positive?),
      contract_total_cents: @snapshot[:contract_total_cents], contracted_recurring_cents: @snapshot[:contracted_recurring_cents]
    }
  end

  def payment_terms
    total = @order.total_cents.to_i
    down = @order.down_payment_cents.to_i
    condition = @order.payment_condition.presence || 'cash'
    {
      payment_condition: condition, payment_method: @order.payment_method, down_payment_cents: down,
      installments_count: @order.installments_count, installments: @installments,
      installment_plan_cents: @installments.pluck(:value), payments: payments(condition, total),
      first_due_date: @first_due_date, balance_cents: total - down, upfront_shipping_cents: 0
    }
  end

  def payments(condition, total)
    return [{ kind: 'cash', date: @first_due_date, value: total }] if condition == 'cash'

    @installments.map { |row| row.merge(kind: 'installment') }
  end
end
