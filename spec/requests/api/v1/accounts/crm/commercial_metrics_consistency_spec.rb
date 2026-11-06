require 'rails_helper'

RSpec.describe 'Commercial indicators use the funnel visibility and creation period', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:jrc_crm_pipeline, account: account) }
  let(:won_stage) { create(:jrc_crm_stage, account: account, pipeline: pipeline, is_won: true, is_terminal: true) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm" }

  before do
    account.enable_features!('jrc_crm')
    [50_000, 434_450, 818_095].each_with_index do |value, index|
      create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: won_stage,
                            owner: index.zero? ? agent : other_agent, status: 'won', value_cents: value, created_at: 60.days.ago)
    end
  end

  it 'consolidates 3 wins and R$13,025.45 for an administrator without a period restriction' do
    headers = admin.create_new_auth_token
    get "#{url}/dashboard", params: { period: 'all', pipeline_id: pipeline.id }, headers: headers
    expect(response).to have_http_status(:ok)
    metrics = response.parsed_body
    expect(metrics).to include('closed_won_count' => 3, 'won_revenue_cents' => 1_302_545,
                               'open_deals_count' => 0, 'pipeline_value_cents' => 0, 'conversion_rate' => 100.0)
    get "#{url}/reports", params: { period: 'all', pipeline_id: pipeline.id }, headers: headers
    expect(response.parsed_body.fetch('summary')).to eq(metrics)
    get "#{url}/deals", params: { pipeline_id: pipeline.id }, headers: headers
    body = response.parsed_body
    rows = body.is_a?(Array) ? body : body.fetch('payload')
    expect(rows.count { |row| row['status'] == 'won' }).to eq(3)
    expect(rows.sum { |row| row['value_cents'] }).to eq(metrics.fetch('won_revenue_cents'))
  end

  it 'restricts an agent to their own wins even if another owner is requested' do
    get "#{url}/dashboard", params: { period: 'all', owner_id: other_agent.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body).to include('closed_won_count' => 1, 'won_revenue_cents' => 50_000)
  end

  it 'explains the legitimate zero when filtering out opportunities created before the last 30 days' do
    headers = admin.create_new_auth_token
    params = { start_date: 30.days.ago.to_date.iso8601, end_date: Date.current.iso8601, pipeline_id: pipeline.id }
    get "#{url}/dashboard", params: params, headers: headers
    expect(response.parsed_body).to include('closed_won_count' => 0, 'won_revenue_cents' => 0)
    get "#{url}/deals", params: params, headers: headers
    expect(response.parsed_body).to eq([])
    expect(account.jrc_crm_deals.won.count).to eq(3)
  end

  it 'does not include another account and applies owner filters to the administrator' do
    other_account = create(:account)
    other_owner = create(:user, account: other_account)
    other_pipeline = create(:jrc_crm_pipeline, account: other_account)
    other_stage = create(:jrc_crm_stage, account: other_account, pipeline: other_pipeline)
    create(:jrc_crm_deal, account: other_account, owner: other_owner, pipeline: other_pipeline, stage: other_stage, status: 'won')
    get "#{url}/dashboard", params: { period: 'all', owner_id: agent.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('closed_won_count' => 1, 'won_revenue_cents' => 50_000)
  end

  it 'classifies a new opportunity created directly in a won stage without rewriting existing history' do
    post "#{url}/deals", params: { deal: { title: 'Venda criada na etapa ganha', pipeline_id: pipeline.id,
                                           stage_id: won_stage.id, value_cents: 12_345 } },
                         headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:created)
    record = account.jrc_crm_deals.find_by!(title: 'Venda criada na etapa ganha')
    expect(record).to have_attributes(status: 'won', stage_id: won_stage.id)
    expect(record.won_at).to be_present
  end

  it 'calculates lost outcomes, conversion and average ticket without counting a zero-probability deal as expected revenue' do
    lost_stage = create(:jrc_crm_stage, account: account, pipeline: pipeline, is_lost: true, is_terminal: true, probability: 0)
    reason = create(:jrc_crm_lost_reason, account: account)
    create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: lost_stage, owner: agent, lost_reason: reason, value_cents: 20_000)
    open_stage = create(:jrc_crm_stage, account: account, pipeline: pipeline, probability: 0)
    create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: open_stage, owner: agent, value_cents: 10_000)
    get "#{url}/dashboard", params: { period: 'all', pipeline_id: pipeline.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('closed_won_count' => 3, 'closed_lost_count' => 1, 'conversion_rate' => 75.0,
                                            'average_ticket_cents' => 434_182, 'weighted_value_cents' => 0, 'pipeline_value_cents' => 10_000)
  end

  it 'keeps corporate coverage restrictive even for an administrator viewing the consolidated result' do
    allowed_company = account.master_companies.create!(name: 'Empresa autorizada', relationship_type: 'internal')
    forbidden_company = account.master_companies.create!(name: 'Empresa restrita', relationship_type: 'internal')
    allowed_unit = account.jrc_crm_business_units.create!(name: 'Unidade A', code: 'metrics-a', company_id: allowed_company.id)
    forbidden_unit = account.jrc_crm_business_units.create!(name: 'Unidade B', code: 'metrics-b', company_id: forbidden_company.id)
    JrcCrm::UserBusinessUnit.create!(account: account, user: admin, scope: 'COMPANY', company_id: allowed_company.id, structure_managed: true)
    create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: won_stage, owner: agent, metadata: { business_unit_id: allowed_unit.id },
                          value_cents: 25_000)
    create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: won_stage, owner: other_agent,
                          metadata: { business_unit_id: forbidden_unit.id }, value_cents: 100_000)
    get "#{url}/dashboard", params: { period: 'all' }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('closed_won_count' => 1, 'won_revenue_cents' => 25_000)
    get "#{url}/reports", params: { period: 'all' }, headers: admin.create_new_auth_token
    expect(response.parsed_body.fetch('summary')).to include('closed_won_count' => 1, 'won_revenue_cents' => 25_000)
  end

  it 'identifies identically named or legacy stages by pipeline without deleting an empty Lead stage' do
    pipeline.update!(name: 'GoPure', position: 1)
    legacy = create(:jrc_crm_pipeline, account: account, name: 'Legacy', key: 'legacy', position: 2)
    lead_stage = create(:jrc_crm_stage, account: account, pipeline: legacy, name: 'Lead', position: 1)
    headers = admin.create_new_auth_token
    get "#{url}/dashboard", params: { period: 'all' }, headers: headers
    stages = response.parsed_body.fetch('funnel_stages')
    expect(stages.find { |row| row['id'] == lead_stage.id }).to include('name' => 'Lead', 'pipeline_id' => legacy.id,
                                                                        'pipeline_name' => 'Legacy', 'deals_count' => 0)
    get "#{url}/stages", params: { pipeline_id: legacy.id }, headers: headers
    expect(response.parsed_body.find { |row| row['id'] == lead_stage.id }).to include('pipeline_id' => legacy.id, 'pipeline_name' => 'Legacy')
    get "#{url}/dashboard", params: { period: 'all', pipeline_id: pipeline.id }, headers: headers
    expect(response.parsed_body.fetch('funnel_stages').map { |row| row['id'] }).not_to include(lead_stage.id)
    expect(lead_stage.reload).to be_persisted
  end
end
