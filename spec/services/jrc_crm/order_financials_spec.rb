require 'rails_helper'

RSpec.describe JrcCrm::OrderFinancials do
  let(:attributes) { {} }
  let(:items) { [] }
  subject(:result) { described_class.new(attributes: attributes, items: items).call }

  context 'direct sale of 100 units at R$20' do
    let(:items) { [{ name: 'Produto', quantity: 100, unit_cents: 2000, snapshot: { billing_model: 'one_time' } }] }
    it 'calculates the initial amount without recurrence' do
      expect(result).to include(products_cents: 200_000, total_cents: 200_000, monthly_cents: 0, contract_total_cents: 200_000)
    end
  end

  context '20 extensions at R$39 with R$50 activation each' do
    let(:items) do
      [{ name: 'Ramal', quantity: 20, unit_cents: 3900,
         snapshot: { billing_model: 'monthly', setup_fee_cents: 5000, contract_term_months: 12 } }]
    end
    it 'keeps the fixed setup and first billing period in the initial amount, with MRR reported separately' do
      expect(result).to include(total_cents: 83_000, monthly_cents: 78_000, contract_total_cents: 83_000)
    end
    it 'does not double count when recalculating persisted items' do
      replay = described_class.new(attributes: attributes, items: result[:items]).call
      expect(replay).to eq(result)
    end
  end

  context 'a mixed order' do
    let(:items) do
      [{ name: 'Produto', quantity: 100, unit_cents: 2000, snapshot: { billing_model: 'one_time' } },
       { name: 'Ramal', quantity: 20, unit_cents: 3900, snapshot: { billing_model: 'monthly', requires_implementation: true } },
       { name: 'Consultoria', quantity: 5, unit_cents: 15_000, snapshot: { billing_model: 'one_time' } }]
    end
    it 'includes the first billing period without multiplying the initial amount by an unspecified contract term' do
      expect(result).to include(total_cents: 353_000, monthly_cents: 78_000, contract_total_cents: 353_000)
    end
  end

  context 'financial adjustments' do
    let(:attributes) { { discount_cents: 20_000, shipping_cents: 10_000, snapshot: { taxes_percent: 10, surcharge_cents: 500 } } }
    let(:items) { [{ name: 'Equipamento', quantity: 1, unit_cents: 250_000 }] }
    it 'applies each adjustment exactly once' do
      expect(result).to include(products_cents: 250_000, discount_cents: 20_000, shipping_cents: 10_000,
                               taxes_cents: 24_000, total_cents: 264_500)
      expect(result[:payments].sum { |i| i[:value] }).to eq(264_500)
    end
  end

  it 'normalizes annual billing and supports fractional quantities' do
    annual = described_class.new(attributes: {}, items: [{ quantity: 2.5, unit_cents: 120_000, snapshot: { billing_model: 'annual' } }]).call
    expect(annual).to include(total_cents: 300_000, monthly_cents: 25_000)
  end

  it 'rejects invalid quantities and discounts' do
    expect { described_class.new(attributes: {}, items: [{ quantity: 0, unit_cents: 100 }]).call }.to raise_error(ArgumentError)
    expect { described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 100, discount_percent: 101 }]).call }.to raise_error(ArgumentError)
  end

  it 'rejects quantities beyond the storage precision instead of changing the amount after save' do
    expect { described_class.new(attributes: {}, items: [{ quantity: '1.2345', unit_cents: 1000 }]).call }.to raise_error(ArgumentError, /tres casas/)
  end

  it 'rejects fractional or nonnumeric contract terms instead of truncating them' do
    [12.5, '12 meses'].each do |term|
      expect { described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 3900, snapshot: { billing_model: 'monthly', contract_term_months: term } }]).call }.to raise_error(ArgumentError)
    end
  end

  it 'preserves the independently specified manual recurring amount' do
    value = described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 3000, recurring_cents: 3000,
                                                         snapshot: { billing_model: 'one_time' } }]).call
    expect(value).to include(total_cents: 3000, monthly_cents: 3000)
  end
  it 'preserves the annual contract price instead of multiplying rounded MRR' do
    value = described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 10_000,
      snapshot: { billing_model: 'annual', contract_term_months: 12 } }]).call
    expect(value).to include(monthly_cents: 833, contract_total_cents: 10_000)
  end

  it 'keeps a positive annual contractual amount even when displayed MRR rounds to zero' do
    value = described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 1,
      snapshot: { billing_model: 'annual', contract_term_months: 12 } }]).call
    expect(value).to include(monthly_cents: 0, total_cents: 1)
  end

  it 'keeps the first annual price exact after quantity and item discount' do
    value = described_class.new(attributes: {}, items: [{ quantity: 3, unit_cents: 10_001, discount_cents: 1000,
      snapshot: { billing_model: 'annual', contract_term_months: 18 } }]).call
    expect(value[:contract_total_cents]).to eq(29_003)
  end

  it 'rejects unknown explicit billing models rather than silently creating a one-time sale' do
    expect { described_class.new(attributes: {}, items: [{ quantity: 1, unit_cents: 100,
      snapshot: { billing_model: 'montly' } }]).call }.to raise_error(ArgumentError)
  end

  it 'rejects percentages above 100 even when the initial base is zero' do
    expect { described_class.new(attributes: { snapshot: { discount_percent: 101 } },
      items: [{ quantity: 1, unit_cents: 0 }]).call }.to raise_error(ArgumentError)
    expect { described_class.new(attributes: {},
      items: [{ quantity: 1, unit_cents: 0, discount_percent: 101 }]).call }.to raise_error(ArgumentError)
  end

  it 'uses the validated integer term instead of truncating numeric strings' do
    result = described_class.new(attributes: {}, items: [{name: 'Mensal', quantity: 1, unit_cents: 1000,
      snapshot: {billing_model: 'monthly', contract_term_months: '1e2'}}]).call
    expect(result[:contract_total_cents]).to eq(1000)
    expect(result[:items].first[:snapshot][:contract_term_months]).to eq(100)
  end

end
