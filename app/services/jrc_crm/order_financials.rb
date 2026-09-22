module JrcCrm
  class OrderFinancials
    def initialize(attributes:, items:)
      @attributes = attributes.with_indifferent_access
      @items = items.map { |item| item.with_indifferent_access }
    end

    def call
      items = @items.map { |item| normalize_item(item) }
      snapshot = (@attributes[:snapshot] || {}).with_indifferent_access
      products = items.sum { |item| item[:one_time_cents] }
      discount = if snapshot.key?(:discount_percent)
                   (products * snapshot[:discount_percent].to_d / 100).round
                 else
                   @attributes[:discount_cents].to_i
                 end
      shipping = @attributes[:shipping_cents].to_i
      taxable = [products + shipping - discount, 0].max
      taxes = (taxable * snapshot[:taxes_percent].to_d / 100).round
      total = taxable + taxes
      count = @attributes[:installments_count].to_i.clamp(1, 120)
      due_date = snapshot[:first_due_date].present? ? Date.iso8601(snapshot[:first_due_date]) : Date.current
      quotient, remainder = total.divmod(count)
      installments = Array.new(count) do |index|
        { number: index + 1, date: (due_date >> index).iso8601,
          value: quotient + (index < remainder ? 1 : 0), status: 'Pendente' }
      end
      { items: items, products_cents: products, shipping_cents: shipping, discount_cents: discount,
        taxes_cents: taxes, total_cents: total, monthly_cents: items.sum { |item| item[:recurring_cents] },
        installments_count: count, installments: installments }
    end

    def normalize_item(item)
      quantity = (item[:quantity] || 1).to_d
      unit = item[:unit_cents].to_i
      gross = (unit * quantity).round
      discount = item.key?(:discount_percent) ? (gross * item[:discount_percent].to_d / 100).round : item[:discount_cents].to_i
      net = [gross - discount, 0].max
      snapshot = (item[:snapshot] || {}).with_indifferent_access
      billing = snapshot[:billing_model]
      recurring = %w[monthly annual usage].include?(billing)
      monthly = recurring ? (billing == 'annual' ? (net.to_d / 12).round : net) : item[:recurring_cents].to_i
      { product_id: item[:product_id], name: item[:name], quantity: quantity, unit_cents: unit,
        discount_cents: discount, one_time_cents: recurring ? snapshot[:setup_fee_cents].to_i : net,
        recurring_cents: monthly, snapshot: snapshot }
    end
  end
end
