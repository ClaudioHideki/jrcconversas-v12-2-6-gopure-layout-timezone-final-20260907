require 'rails_helper'

RSpec.describe 'Commercial funnel records match the summary without changing deal stages', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:jrc_crm_pipeline, account: account) }
  let(:stage) { create(:jrc_crm_stage, account: account, pipeline: pipeline, key: 'negotiation') }
  let(:deal) { create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: stage, owner: agent, value_cents: 12_345) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }

  before { account.enable_features!('jrc_crm') }

  it 'shows four qualified leads and all sent documents, including accepted, canceled and won/lost origins' do
    create_list(:jrc_crm_lead, 4, account: account, owner: agent, status: 'qualified')
    create(:jrc_crm_lead, account: account, owner: agent, status: 'new')
    won = create(:jrc_crm_won_stage, account: account, pipeline: pipeline)
    lost = create(:jrc_crm_lost_stage, account: account, pipeline: pipeline)
    won_deal = create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: won, owner: agent, value_cents: 5000)
    lost_deal = create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: lost, owner: agent,
                                      lost_reason: create(:jrc_crm_lost_reason, account: account), value_cents: 3000)
    sent = create(:jrc_crm_proposal, account: account, deal: deal, owner: agent, status: 'sent', sent_at: Time.current)
    accepted = create(:jrc_crm_proposal, account: account, deal: won_deal, owner: agent, status: 'sent', sent_at: Time.current)
    accepted.accept_by_customer!(name: 'Synthetic customer', document: 'QA', remote_ip: '127.0.0.1', user_agent: 'QA')
    canceled = create(:jrc_crm_proposal, account: account, deal: lost_deal, owner: agent, status: 'canceled', sent_at: Time.current)
    create(:jrc_crm_proposal, account: account, deal: deal, owner: agent)
    before_stages = [deal, won_deal, lost_deal].map { |row| row.slice(:id, :stage_id, :status, :value_cents) }
    before_events = JrcCrm::AuditEvent.count

    get "#{base}/funnel_records", params: { period: 'all' }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    records = response.parsed_body
    expect(records.fetch('qualified_leads').length).to eq(4)
    expect(records.fetch('sent_proposals').map { |row| row.values_at('id', 'status', 'pipeline_id') }).to contain_exactly(
      [sent.id, 'sent', pipeline.id], [accepted.id, 'accepted', pipeline.id], [canceled.id, 'canceled', pipeline.id]
    )
    expect(records.to_json).not_to include('public_token', 'accepted_by_document', 'accepted_from_ip')

    get "#{base}/dashboard", params: { period: 'all' }, headers: admin.create_new_auth_token
    metrics = response.parsed_body
    expect([metrics.fetch('funnel_records'), metrics.dig('commercial_summary', 'leads', 'qualified'),
            metrics.dig('commercial_summary', 'proposals_sent_count'), metrics.fetch('pipeline_value_cents')]).to eq([records, 4, 3, 12_345])
    expect([deal, won_deal, lost_deal].map { |row| row.reload.slice(:id, :stage_id, :status, :value_cents) }).to eq(before_stages)
    expect(JrcCrm::AuditEvent.count).to eq(before_events)
  end

  it 'keeps agent ownership and account isolation even when another owner is requested' do
    own = create(:jrc_crm_lead, account: account, owner: agent, status: 'qualified')
    create(:jrc_crm_lead, account: account, owner: admin, status: 'qualified')
    own_proposal = create(:jrc_crm_proposal, account: account, deal: deal, owner: agent, sent_at: Time.current)
    create(:jrc_crm_proposal, account: account, deal: deal, owner: admin, sent_at: Time.current)
    foreign = create(:account)
    foreign_owner = create(:user, account: foreign)
    create(:jrc_crm_lead, account: foreign, owner: foreign_owner, status: 'qualified')
    get "#{base}/funnel_records", params: { period: 'all', owner_id: admin.id }, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('qualified_leads').map { |row| row['id'] }).to eq([own.id])
    expect(response.parsed_body.fetch('sent_proposals').map { |row| row['id'] }).to eq([own_proposal.id])
    get "#{base}/funnel_records", params: { period: 'all', search: own.email }, headers: agent.create_new_auth_token
    expect(response.parsed_body.fetch('qualified_leads').map { |row| row['id'] }).to eq([own.id])
  end

  it 'uses the same pipeline and creation dates as the indicators, including direct documents only without a pipeline filter' do
    create(:jrc_crm_lead, account: account, owner: agent, status: 'qualified', created_at: 90.days.ago)
    recent = create(:jrc_crm_lead, account: account, owner: agent, status: 'qualified')
    create(:jrc_crm_proposal, account: account, deal: deal, owner: agent, sent_at: Time.current, created_at: 90.days.ago)
    direct = account.jrc_crm_proposals.create!(owner: agent, contact: create(:contact, account: account), title: 'Direct QA', sent_at: Time.current)
    params = { start_date: Date.current.iso8601, end_date: Date.current.iso8601, pipeline_id: pipeline.id }
    get "#{base}/funnel_records", params: params, headers: admin.create_new_auth_token
    expect(response.parsed_body.fetch('qualified_leads').map { |row| row['id'] }).to eq([recent.id])
    expect(response.parsed_body.fetch('sent_proposals')).to eq([])
    get "#{base}/dashboard", params: params, headers: admin.create_new_auth_token
    expect(response.parsed_body.dig('commercial_summary', 'proposals_sent_count')).to eq(0)
    get "#{base}/funnel_records", params: { period: 'all', search: 'Direct QA' }, headers: admin.create_new_auth_token
    expect(response.parsed_body.fetch('sent_proposals').map { |row| row['id'] }).to eq([direct.id])
    expect(response.parsed_body.fetch('sent_proposals').first['pipeline_id']).to be_nil
  end

  it 'provides open aggregates independently of stored stage order while retaining closed values' do
    won = create(:jrc_crm_won_stage, account: account, pipeline: pipeline)
    closed = create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: won, owner: agent, value_cents: 40_000)
    original = [deal, closed].map { |row| row.slice(:id, :stage_id, :status, :value_cents) }
    get "#{base}/dashboard", params: { period: 'all' }, headers: admin.create_new_auth_token
    rows = response.parsed_body.fetch('funnel_stages')
    expect(rows.find { |row| row['id'] == stage.id }).to include('open_deals_count' => 1, 'open_value_cents' => 12_345)
    expect(rows.find { |row| row['id'] == won.id }).to include('deals_count' => 1, 'value_cents' => 40_000,
                                                           'open_deals_count' => 0, 'open_value_cents' => 0)
    expect([deal, closed].map { |row| row.reload.slice(:id, :stage_id, :status, :value_cents) }).to eq(original)
  end

  it 'does not expose records when CRM access is disabled' do
    account.disable_features!('jrc_crm')
    get "#{base}/funnel_records", params: { period: 'all' }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end
end
