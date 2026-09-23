require 'rails_helper'

RSpec.describe 'CRM goals dashboard criteria', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/goals/dashboard" }
  let(:period) { { period_start: Date.new(2026, 9, 1), period_end: Date.new(2026, 9, 30) } }
  let(:goal) do
    JrcCrm::SalesGoal.create!(account: account, status: 'active', metric: 'revenue', scope_kind: 'team',
      target_cents: 30_000, allocations: [{ user_id: agent.id, target_cents: 10_000 }, { user_id: admin.id, target_cents: 20_000 }], **period)
  end

  before do
    account.enable_features!('jrc_crm')
    [agent, admin].each do |owner|
      order = account.jrc_crm_sales_orders.create!(owner: owner, source_type: 'manual', status: 'completed',
        sold_at: Time.zone.parse('2026-09-23 12:00'), total_cents: 20_000, monthly_cents: 3000)
      order.order_items.create!(name: 'Produto', quantity: 100, one_time_cents: 20_000)
    end
  end

  it 'uses the selected goal for the cards and the same criteria for the chart' do
    goal.update!(settings: { order_statuses: ['approved'] })
    get url, params: { goal_id: goal.id, start_date: '2026-09-01', end_date: '2026-09-30' }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['realized']).to eq(0)
    expect(response.parsed_body['evolution'].last['realized_cents']).to eq(0)
    expect(response.parsed_body.dig('goals', 0, 'criteria', 'order_statuses')).to eq(['approved'])
  end

  it 'returns agent progress and ranking without exposing other agents sales' do
    get url, params: { goal_id: goal.id, start_date: '2026-09-01', end_date: '2026-09-30' }, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('realized' => 20_000, 'target' => 10_000)
    expect(response.parsed_body['ranking'].map { |r| r['user_id'] }).to eq([agent.id])
    expect(response.parsed_body['evolution'].last['realized_cents']).to eq(20_000)
  end

  it 'returns quantities without silently discarding them as non monetary goals' do
    quantity = JrcCrm::SalesGoal.create!(account: account, status: 'active', metric: 'quantity', scope_kind: 'company',
      target_cents: 0, target_quantity: 300, **period)
    get url, params: { goal_id: quantity.id, start_date: '2026-09-01', end_date: '2026-09-30' }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('metric' => 'quantity', 'target' => 300, 'realized' => 200)
    expect(response.parsed_body['evolution'].last['realized_cents']).to eq(200)
  end
end
