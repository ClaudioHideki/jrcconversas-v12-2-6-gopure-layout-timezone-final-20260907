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
      discount = if snapshot[:discount_percent].present?
                   (products * nonnegative!(snapshot[:discount_percent], 'Desconto') / 100).round
                 else
                   nonnegative!(@attributes[:discount_cents] || 0, 'Desconto').round
                 end
      raise ArgumentError, 'Desconto inválido.' if discount.negative? || discount > products
      shipping = nonnegative!(@attributes[:shipping_cents] || 0, 'Frete').round
      taxable = [products + shipping - discount, 0].max
      taxes = (taxable * nonnegative!(snapshot[:taxes_percent] || 0, 'Impostos') / 100).round
      surcharge = nonnegative!(snapshot[:surcharge_cents] || 0, 'Acréscimo').round
      total = taxable + taxes + surcharge
      count = @attributes[:installments_count].to_i.clamp(1, 120)
      due_date = snapshot[:first_due_date].present? ? Date.iso8601(snapshot[:first_due_date]) : Date.current
      quotient, remainder = total.divmod(count)
      installments = Array.new(count) do |index|
        { number: index + 1, date: (due_date >> index).iso8601,
          value: quotient + (index < remainder ? 1 : 0), status: 'Pendente' }
      end
      recurring_items = items.select { |item| item[:recurring_cents].positive? }
      known_term = recurring_items.any? && recurring_items.all? { |item| item[:snapshot][:contract_term_months].to_i.positive? }
      contracted = known_term ? recurring_items.sum { |item| item[:recurring_cents] * item[:snapshot][:contract_term_months].to_i } : nil
      { items: items, products_cents: products, shipping_cents: shipping, discount_cents: discount, surcharge_cents: surcharge,
        contracted_recurring_cents: contracted, contract_total_cents: contracted && (total + contracted),
        taxes_cents: taxes, total_cents: total, monthly_cents: items.sum { |item| item[:recurring_cents] },
        installments_count: count, installments: installments }
    end

    def self.recalculate!(order)
      result = new(attributes: order.attributes, items: order.order_items.map(&:attributes)).call
      snapshot = order.snapshot.merge(result.slice(:taxes_cents, :surcharge_cents, :contracted_recurring_cents,
                                                    :contract_total_cents, :installments).stringify_keys)
      order.update!(result.slice(:products_cents, :monthly_cents, :shipping_cents, :discount_cents, :total_cents, :installments_count)
                         .merge(snapshot: snapshot.merge('financial_version' => 2)))
      result
    end

    def normalize_item(item)
      quantity = nonnegative!(item[:quantity] || 1, 'Quantidade')
      raise ArgumentError, 'Quantidade deve ser maior que zero.' unless quantity.positive?
      raise ArgumentError, 'Quantidade permite até três casas decimais.' unless quantity == quantity.round(3)
      unit = nonnegative!(item[:unit_cents] || 0, 'Preço unitário').round
      gross = (unit * quantity).round
      discount = item.key?(:discount_percent) ? (gross * nonnegative!(item[:discount_percent], 'Desconto do item') / 100).round : nonnegative!(item[:discount_cents] || 0, 'Desconto do item').round
      raise ArgumentError, 'Desconto do item inválido.' if discount.negative? || discount > gross
      net = gross - discount
      snapshot = (item[:snapshot] || {}).with_indifferent_access
      if snapshot[:contract_term_months].present?
        months = nonnegative!(snapshot[:contract_term_months], 'Prazo contratual')
        raise ArgumentError, 'Prazo contratual deve ser um número inteiro positivo.' unless months.positive? && months == months.round
      end
      billing = snapshot[:billing_model]
      recurring = %w[monthly annual usage].include?(billing)
      # Unclassified legacy items may already carry a monthly amount. Explicit
      # one-time items must never inherit a stale monthly value from a proposal.
      monthly = recurring ? (billing == 'annual' ? (net.to_d / 12).round : net) : (billing.blank? ? item[:recurring_cents].to_i : 0)
      setup = (nonnegative!(snapshot[:setup_fee_cents] || 0, 'Valor inicial unitário') * quantity).round
      { product_id: item[:product_id], name: item[:name], quantity: quantity, unit_cents: unit,
        discount_cents: discount, one_time_cents: recurring ? setup : net,
        recurring_cents: monthly, snapshot: snapshot }
    end

    private

    def nonnegative!(value, label)
      decimal = BigDecimal(value.to_s)
      raise ArgumentError, "#{label} inválido." unless decimal.finite? && decimal >= 0
      decimal
    end
  end
end
