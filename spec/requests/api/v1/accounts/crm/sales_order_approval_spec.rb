require 'rails_helper'

RSpec.describe 'Sales order approval from order details', type: :request do
  let(:account) { create(:account, name: 'GoPure') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:order) do
    account.jrc_crm_sales_orders.create!(owner: agent, created_by: agent, contact: contact,
      source_type: 'manual', order_origin: 'direct_sale', status: 'pending', total_cents: 12345, snapshot: {})
  end
  let(:url) { "/api/v1/accounts/#{account.id}/crm/sales_orders/#{order.id}" }
  let(:request_record) { order.backoffice_requests.find_by!(request_kind: 'approval') }
  before { account.enable_features!('jrc_crm') }

  it 'exposes approval only to administrators and does not create decisions during reads' do
    order
    expect { get url, headers: admin.create_new_auth_token }.not_to change(JrcCrm::AuditEvent, :count)
    expect(response.parsed_body.dig('approval', 'can_approve')).to be(true)
    get url, headers: agent.create_new_auth_token
    expect(response.parsed_body.dig('approval', 'can_approve')).to be(false)
    expect(request_record).to be_pending
  end

  it 'approves and activates commercially without completing fulfillment or inventing invoices' do
    original = order.attributes.slice('total_cents', 'monthly_cents', 'snapshot', 'contact_id', 'owner_id')
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'approved', 'commercial_status' => 'active', 'commercial_flow' => 'simple')
    expect(order.reload).to be_approved
    expect(order.attributes.slice(*original.keys)).to eq(original)
    expect(request_record.reload).to be_approved
    expect(request_record.metadata.dig('approval_decision', 'actor_id')).to eq(admin.id)
    expect(order.invoices).to be_empty
    expect(order.backoffice_requests.where(request_kind: 'fulfillment', status: 'completed')).to be_empty
    expect(order.backoffice_requests.where(request_kind: 'fulfillment').count).to eq(1)
    event = response.parsed_body['history'].find { |row| row.dig('metadata', 'decision') == 'approved' }
    expect(event.dig('actor', 'id')).to eq(admin.id)
    expect(event.dig('actor', 'name')).to eq(admin.name)
    get "/api/v1/accounts/#{account.id}/crm/sales_orders", headers: admin.create_new_auth_token
    expect(response.parsed_body.find { |row| row['id'] == order.id }['commercial_status']).to eq('active')
  end

  it 'does not duplicate approval, fulfillment or audit on a repeated confirmation' do
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    counts = [order.backoffice_requests.count, order.commissions.count, JrcCrm::AuditEvent.where(account: account).count]
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect([order.backoffice_requests.count, order.commissions.count, JrcCrm::AuditEvent.where(account: account).count]).to eq(counts)
  end

  it 'requires explicit confirmation and denies agents even for their own order' do
    post "#{url}/approve", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{url}/approve", params: { confirmed: true }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(order.reload).to be_pending
    expect(request_record.reload).to be_pending
  end

  it 'preserves commercial approval gates and rolls the whole decision back when blocked' do
    order
    expect(JrcApprovals::CommercialGate).to receive(:check!).with(resource: order, user: admin, key: 'crm.order_price')
      .and_raise(JrcApprovals::Error.new('APPROVAL_REQUIRED'))
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:conflict)
    expect(order.reload).to be_pending
    expect(request_record.reload).to be_pending
    expect(order.backoffice_requests.where(request_kind: 'fulfillment')).to be_empty
  end

  it 'does not reverse a rejection or activate a canceled order' do
    JrcCrm::OrderApprovalService.new(order: order, actor: admin).decide!(request: request_record, decision: 'rejected', reason: 'Revisar')
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(request_record.reload).to be_rejected
    order.update!(status: 'canceled')
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload).to be_canceled
  end

  it 'cannot approve an order from another account' do
    foreign = create(:account)
    foreign_order = foreign.jrc_crm_sales_orders.create!(owner: create(:user, account: foreign), status: 'pending')
    post "/api/v1/accounts/#{account.id}/crm/sales_orders/#{foreign_order.id}/approve",
      params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(foreign_order.reload).to be_pending
  end

  it 'does not expose or approve orders outside an administrator corporate unit coverage' do
    company = account.master_companies.create!(name: 'Empresa permitida', relationship_type: 'internal')
    foreign_company = account.master_companies.create!(name: 'Empresa restrita', relationship_type: 'internal')
    allowed_unit = account.jrc_crm_business_units.create!(name: 'Unidade permitida', code: 'allowed', company_id: company.id)
    blocked_unit = account.jrc_crm_business_units.create!(name: 'Unidade restrita', code: 'blocked', company_id: foreign_company.id)
    JrcCrm::UserBusinessUnit.create!(account: account, user: admin, company: company, scope: 'COMPANY', structure_managed: true)
    order.update!(business_unit: blocked_unit)
    get url, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
    expect(order.reload).to be_pending
    expect(request_record.reload).to be_pending
    permitted_order = account.jrc_crm_sales_orders.create!(owner: admin, created_by: admin, contact: contact,
      business_unit: allowed_unit, source_type: 'manual', order_origin: 'direct_sale', status: 'pending', snapshot: {})
    post "/api/v1/accounts/#{account.id}/crm/sales_orders/#{permitted_order.id}/approve",
      params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(permitted_order.reload).to be_approved
  end

  it 'does not approve a logically hidden order, even when its removal marker is empty' do
    order.update!(snapshot: { removal: {} })
    get url, headers: admin.create_new_auth_token
    expect(response.parsed_body.dig('approval', 'can_approve')).to be(false)
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload).to be_pending
  end

  it 'keeps the operational workflow for other accounts even when they use a GoPure theme' do
    account.update!(name: 'Outra empresa', custom_attributes: { crm_theme: 'gopure' })
    post "#{url}/approve", params: { confirmed: true }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'approved', 'commercial_status' => 'approved', 'commercial_flow' => 'standard')
  end
end
