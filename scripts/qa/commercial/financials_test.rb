# ruby scripts/qa/commercial/financials_test.rb
# Executes the REAL calculator, with test-only ActiveSupport conveniences.
# Database persistence is deliberately NOT claimed by this isolated suite.
require_relative 'standalone_support'
load ENV.fetch('CRM_FINANCIALS_SOURCE', File.expand_path('../../../app/services/jrc_crm/order_financials.rb', __dir__))

class CommercialFinancialsTest < Minitest::Test
  def calculate(items, attributes = {})
    JrcCrm::OrderFinancials.new(attributes: attributes, items: items).call
  end
  def item(billing: 'one_time', quantity: 100, unit: 2000, **snapshot)
    { name: 'QA synthetic item', quantity: quantity, unit_cents: unit,
      snapshot: { billing_model: billing, **snapshot } }
  end

  def test_direct_100_times_20
    result = calculate([item])
    assert_equal 200_000, result[:total_cents]
    assert_equal 0, result[:monthly_cents]
    assert_nil result[:contract_total_cents]
    assert_equal 200_000, result[:installments].sum { |row| row[:value] }
  end
  def test_direct_sale_adjustments_2095
    result = calculate([item], discount_cents: 20_000, shipping_cents: 10_000,
      snapshot: { taxes_percent: 10, surcharge_cents: 500 })
    assert_equal 209_500, result[:total_cents]
    assert_equal 19_000, result[:taxes_cents]
    assert_equal 0, result[:monthly_cents]
  end
  def test_20_recurring_extensions_with_activation
    result = calculate([item(billing: 'monthly', quantity: 20, unit: 3900,
      setup_fee_cents: 5000, contract_term_months: 12)])
    assert_equal 100_000, result[:total_cents]
    assert_equal 78_000, result[:monthly_cents]
    assert_equal 936_000, result[:contracted_recurring_cents]
    assert_equal 1_036_000, result[:contract_total_cents]
  end
  def test_recurrence_is_independent_of_implementation
    [false, true].each do |implementation|
      result = calculate([item(billing: 'monthly', quantity: 2, unit: 2000,
        requires_implementation: implementation)])
      assert_equal 0, result[:total_cents]
      assert_equal 4000, result[:monthly_cents]
      assert_equal implementation, result[:items].first[:snapshot][:requires_implementation]
    end
  end
  def test_one_time_with_implementation_remains_one_time
    result = calculate([item(requires_implementation: true)])
    assert_equal 200_000, result[:total_cents]
    assert_equal 0, result[:monthly_cents]
  end
  def test_mixed_order_and_unknown_term
    result = calculate([item,
      item(billing: 'monthly', quantity: 20, unit: 3900, setup_fee_cents: 5000),
      item(quantity: 5, unit: 15_000)])
    assert_equal 375_000, result[:total_cents]
    assert_equal 78_000, result[:monthly_cents]
    assert_nil result[:contract_total_cents]
  end
  def test_partial_contract_terms_do_not_invent_a_total
    result = calculate([item(billing: 'monthly', contract_term_months: 12), item(billing: 'monthly')])
    assert_nil result[:contract_total_cents]
  end
  def test_fractional_quantities_and_annual_mrr
    result = calculate([item(billing: 'annual', quantity: '2.5', unit: 120_000)])
    assert_equal 25_000, result[:monthly_cents]
    assert_equal 0, result[:total_cents]
  end
  def test_annual_contract_does_not_multiply_a_rounded_mrr
    result = calculate([item(billing: 'annual', quantity: 1, unit: 10_000, contract_term_months: 12)])
    assert_equal 833, result[:monthly_cents]
    assert_equal 10_000, result[:contracted_recurring_cents]
  end
  def test_tiny_annual_contract_is_not_lost_when_mrr_rounds_to_zero
    result = calculate([item(billing: 'annual', quantity: 1, unit: 1, contract_term_months: 12)])
    assert_equal 0, result[:monthly_cents]
    assert_equal 1, result[:contracted_recurring_cents]
  end
  def test_annual_contract_accounts_for_item_discount_and_term
    row = item(billing: 'annual', quantity: 3, unit: 10_001, contract_term_months: 18)
    row[:discount_cents] = 1000
    result = calculate([row])
    assert_equal 43_505, result[:contracted_recurring_cents]
  end
  def test_percentage_and_fixed_discounts
    row = item
    row[:discount_percent] = 10
    result = calculate([row], snapshot: { discount_percent: 10 })
    assert_equal 180_000, result[:products_cents]
    assert_equal 18_000, result[:discount_cents]
    assert_equal 162_000, result[:total_cents]
  end
  def test_installments_sum_exactly_and_roll_dates
    result = calculate([item(quantity: 1, unit: 100)], installments_count: 3, snapshot: { first_due_date: '2026-01-31' })
    assert_equal [34, 33, 33], result[:installments].map { |row| row[:value] }
    assert_equal ['2026-01-31', '2026-02-28', '2026-03-31'], result[:installments].map { |row| row[:date] }
  end
  def test_json_round_trip_recalculation_is_stable
    first = calculate([item, item(billing: 'annual', quantity: '1.25', unit: 10_001, setup_fee_cents: 400, contract_term_months: 18)])
    # Serialize the normalized items, NOT a pretend database record.
    replay = JSON.parse(JSON.generate(first[:items]))
    second = calculate(replay)
    %i[products_cents total_cents monthly_cents contract_total_cents].each { |key| assert_equal first[key], second[key] }
  end
  def test_explicit_one_time_does_not_inherit_stale_mrr
    row = item; row[:recurring_cents] = 9000
    assert_equal 0, calculate([row])[:monthly_cents]
  end
  def test_legacy_unclassified_item_keeps_recurring_amount
    row = item; row[:snapshot] = {}; row[:recurring_cents] = 9000
    assert_equal 9000, calculate([row])[:monthly_cents]
  end
  def test_invalid_quantity_or_precision_is_rejected
    [0, -1, '1.2345', 'NaN', 'Infinity', 'nonnumeric'].each do |quantity|
      assert_raises(ArgumentError) { calculate([item(quantity: quantity)]) }
    end
  end
  def test_invalid_money_is_rejected
    [-1, 'NaN', 'Infinity', 'bad'].each do |value|
      assert_raises(ArgumentError) { calculate([item(unit: value)]) }
      assert_raises(ArgumentError) { calculate([item], shipping_cents: value) }
    end
  end
  def test_invalid_contract_terms_are_rejected
    [-1, 0, 12.5, '12 months'].each do |term|
      assert_raises(ArgumentError) { calculate([item(billing: 'monthly', contract_term_months: term)]) }
    end
  end
  def test_discount_cannot_exceed_the_initial_amount
    assert_raises(ArgumentError) { calculate([item], discount_cents: 200_001) }
    row = item; row[:discount_percent] = 101
    assert_raises(ArgumentError) { calculate([row]) }
  end
  def test_invalid_billing_model_is_not_silently_changed_to_one_time
    assert_raises(ArgumentError) { calculate([item(billing: 'montly')]) }
  end
  def test_discount_percent_is_validated_even_on_zero_base
    assert_raises(ArgumentError) { calculate([item(unit: 0)], snapshot: { discount_percent: 101 }) }
    row = item(unit: 0); row[:discount_percent] = 101
    assert_raises(ArgumentError) { calculate([row]) }
  end
  def test_contract_term_is_used_as_the_validated_integer_not_a_truncated_string
    result = calculate([item(billing: 'monthly', quantity: 1, unit: 1000, contract_term_months: '1e2')])
    assert_equal 100_000, result[:contracted_recurring_cents]
    assert_equal 100, result[:items].first[:snapshot][:contract_term_months]
  end

end
