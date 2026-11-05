require 'rails_helper'

RSpec.describe 'Commercial summary separates approval, signature and pipeline', type: :request do
  let(:account) { create(:account, name: 'GoPure') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }
  before { account.enable_features!('jrc_crm', 'jrc_customer_master') }

  it 'identifies the GoPure commercial flow even when there are no orders' do
    get "#{base}/sales_orders", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
    expect(response.headers['X-Jrc-Commercial-Flow']).to eq('simple')
  end

  it 'counts revenue only from approved operational statuses, excluding pending, canceled and removed orders' do
    %w[draft pending approved separating invoiced shipped completed canceled].each do |status|
      account.jrc_crm_sales_orders.create!(owner: agent, contact: contact, source_type: 'manual', order_origin: 'direct_sale',
        status: status, total_cents: 1000, snapshot: {})
    end
    account.jrc_crm_sales_orders.create!(owner: agent, contact: contact, source_type: 'manual', order_origin: 'direct_sale',
      status: 'canceled', total_cents: 9000, snapshot: { removal: { reason: 'Synthetic QA' } })
    get "#{base}/dashboard", params: { period: 'all' }, headers: admin.create_new_auth_token
    summary = response.parsed_body.fetch('commercial_summary')
    expect(summary.fetch('orders')).to include('total_count' => 8, 'active_count' => 5, 'pending_count' => 2, 'revenue_cents' => 5000)
    get "#{base}/reports", params: { period: 'all' }, headers: admin.create_new_auth_token
    expect(response.parsed_body.dig('summary', 'commercial_summary')).to eq(summary)
  end

  it 'counts public signatures once despite duplicate events, excluding manual acceptance and unsigned wins' do
    signed = account.jrc_crm_proposals.create!(owner: agent, contact: contact, title: 'Signed synthetic', status: 'sent',
      accepted_at: Time.current, accepted_by_name: 'Synthetic signer', accepted_by_document: 'QA-document', total_cents: 12345, sent_at: Time.current)
    signed.accept_by_customer!(name: 'Synthetic signer', document: 'QA-document', remote_ip: '127.0.0.1', user_agent: 'QA')
    2.times { signed.events.create!(account: account, event_type: 'accepted', description: 'Synthetic QA acceptance', metadata: { acceptance_origin: 'public_link' }) }
    manual = account.jrc_crm_proposals.create!(owner: agent, contact: contact, title: 'Manual', status: 'sent',
      accepted_at: Time.current, accepted_by_name: 'Synthetic signer', accepted_by_document: 'QA-document', total_cents: 90000, sent_at: Time.current)
    manual.accept_by_customer!(name: 'Synthetic signer', document: 'QA-document', remote_ip: '127.0.0.1', user_agent: 'QA')
    manual.events.create!(account: account, user: admin, event_type: 'accepted', description: 'Synthetic QA acceptance')
    get "#{base}/dashboard", params: { period: 'all' }, headers: agent.create_new_auth_token
    expect(response.parsed_body.dig('commercial_summary', 'signed_proposals')).to eq('count' => 1, 'value_cents' => 12345)
    expect(response.parsed_body.dig('commercial_summary', 'proposals_sent_count')).to eq(2)
    expect(response.parsed_body.dig('commercial_summary', 'orders', 'revenue_cents')).to eq(0)
    get "#{base}/dashboard", params: { period: 'all', owner_id: agent.id }, headers: create(:user, account: account, role: :agent).create_new_auth_token
    expect(response.parsed_body.dig('commercial_summary', 'signed_proposals', 'count')).to eq(0)
  end

  it 'limits documents to the selected pipeline and never includes another account' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: agent, pipeline: pipeline, stage: stage)
    account.jrc_crm_proposals.create!(owner: agent, deal: deal, title: 'In pipeline', sent_at: Time.current)
    account.jrc_crm_proposals.create!(owner: agent, contact: contact, title: 'Direct sale', sent_at: Time.current)
    get "#{base}/dashboard", params: { period: 'all', pipeline_id: pipeline.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body.dig('commercial_summary', 'proposals_sent_count')).to eq(1)
    get "#{base}/reports", params: { period: 'all', owner_id: agent.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body.fetch('proposals_by_status')).to include('name' => 'draft', 'count' => 2)
  end

  it 'does not expose another owners sent document count in a visible deal card' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: agent, pipeline: pipeline, stage: stage)
    account.jrc_crm_proposals.create!(owner: admin, deal: deal, title: 'Restricted synthetic proposal', sent_at: Time.current)
    get "#{base}/deals", headers: agent.create_new_auth_token
    expect(response.parsed_body.first.fetch('proposals_sent_count')).to eq(0)
    get "#{base}/deals", headers: admin.create_new_auth_token
    expect(response.parsed_body.first.fetch('proposals_sent_count')).to eq(1)
  end

  it 'shows unconverted qualified leads, respecting ownership and creation dates without creating deals' do
    qualified = create(:jrc_crm_lead, account: account, owner: agent, status: 'qualified')
    create(:jrc_crm_lead, account: account, owner: admin, status: 'qualified')
    create(:jrc_crm_lead, account: account, owner: agent, status: 'converted')
    get "#{base}/leads", params: { funnel: 'true', period: 'all', owner_id: admin.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body).to eq([])
    expect { get "#{base}/leads", params: { funnel: 'true', period: 'all' }, headers: agent.create_new_auth_token }
      .not_to change(JrcCrm::Deal, :count)
    expect(response.parsed_body).to eq([{ 'id' => qualified.id, 'name' => qualified.name, 'status' => 'qualified' }])
    get "#{base}/leads", params: { funnel: 'true', start_date: 1.day.from_now.to_date.iso8601 }, headers: agent.create_new_auth_token
    expect(response.parsed_body).to eq([])
  end
end
