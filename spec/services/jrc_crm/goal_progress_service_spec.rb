require 'rails_helper'

RSpec.describe JrcCrm::GoalProgressService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:other_owner) { create(:user, account: account) }
  let(:product) { create(:jrc_crm_product, account: account) }
  let(:goal) do
    JrcCrm::SalesGoal.create!(account: account, user: owner, metric: 'revenue', scope_kind: 'user',
      period_start: Date.new(2026, 9, 1), period_end: Date.new(2026, 9, 30), target_cents: 100_000,
      calculation_method: 'completed_orders')
  end
  let!(:order) do
    JrcCrm::SalesOrder.create!(account: account, owner: owner, source_type: 'manual', status: 'completed',
      sold_at: Time.zone.parse('2026-09-23 12:00'), total_cents: 20_000, monthly_cents: 3000)
  end

  it 'counts multiple completed sales once and respects account, owner, period and status' do
    JrcCrm::SalesOrder.create!(account: account, owner: owner, source_type: 'manual', status: 'completed',
      sold_at: order.sold_at, total_cents: 20_000)
    JrcCrm::SalesOrder.create!(account: account, owner: other_owner, source_type: 'manual', status: 'completed',
      sold_at: order.sold_at, total_cents: 900_000)
    JrcCrm::SalesOrder.create!(account: account, owner: owner, source_type: 'manual', status: 'pending',
      sold_at: order.sold_at, total_cents: 900_000)
    JrcCrm::SalesOrder.create!(account: account, owner: owner, source_type: 'manual', status: 'completed',
      sold_at: Time.zone.parse('2026-08-31 12:00'), total_cents: 900_000)
    foreign = create(:account)
    JrcCrm::SalesOrder.create!(account: foreign, owner: create(:user, account: foreign), source_type: 'manual',
      status: 'completed', sold_at: order.sold_at, total_cents: 900_000)
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_won_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: stage, owner: owner, status: 'won', value_cents: 20_000)
    order.update!(deal: deal, contact: deal.contact)
    expect(described_class.new(goal: goal).call[:realized]).to eq(40_000)
    goal.update!(metric: 'mrr')
    expect(described_class.new(goal: goal).call[:realized]).to eq(3000)
  end

  it 'counts equal-value orders once each with product filtering and excludes unrelated item quantities' do
    goal.update!(product: product)
    2.times { order.order_items.create!(product: product, name: 'Produto', quantity: 2, one_time_cents: 5000) }
    order.order_items.create!(name: 'Outro', quantity: 99, one_time_cents: 10_000)
    second = JrcCrm::SalesOrder.create!(account: account, owner: owner, source_type: 'manual', status: 'completed',
      sold_at: order.sold_at, total_cents: 20_000)
    second.order_items.create!(product: product, name: 'Produto', quantity: 1, one_time_cents: 20_000)
    expect(described_class.new(goal: goal).call[:realized]).to eq(40_000)
    goal.update!(metric: 'quantity')
    expect(described_class.new(goal: goal).call[:realized]).to eq(5)
  end

  it 'limits a team goal to its members and applies the same scope to product totals' do
    team = create(:team, account: account)
    team.members << owner
    goal.update!(user: nil, team: team, scope_kind: 'team', product_targets: [{ product_id: product.id, target_cents: 100_000 }])
    order.order_items.create!(product: product, name: 'Produto', quantity: 1, one_time_cents: 20_000)
    outsider = JrcCrm::SalesOrder.create!(account: account, owner: other_owner, source_type: 'manual', status: 'completed',
      sold_at: order.sold_at, total_cents: 900_000)
    outsider.order_items.create!(product: product, name: 'Produto', quantity: 1, one_time_cents: 900_000)
    result = described_class.new(goal: goal).call
    expect(result[:realized]).to eq(20_000)
    expect(result[:product_results].first[:realized_cents]).to eq(20_000)
  end

  it 'preserves explicit historical status filters instead of including pending or canceled sales' do
    goal.update!(settings: { order_statuses: ['approved', 'invoiced'] })
    expect(described_class.new(goal: goal).call[:realized]).to eq(0)
  end
end
