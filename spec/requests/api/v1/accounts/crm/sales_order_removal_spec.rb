require 'rails_helper'

RSpec.describe 'Logical order removal', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:order) { account.jrc_crm_sales_orders.create!(owner: admin, status: 'draft', snapshot: {}) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/sales_orders" }
  let(:headers) { admin.create_new_auth_token }
  before { account.enable_features!('jrc_crm') }

  it 'requires explicit confirmation and a reason, without modifying the order on failure' do
    post "#{url}/remove", params: { ids: [order.id], reason: 'Duplicado' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{url}/remove", params: { ids: [order.id], confirmed: true, reason: ' ' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload.snapshot).not_to have_key('removal')
  end

  it 'cancels and hides the order while retaining its previous status, values, details and audit' do
    id = order.id
    post "#{url}/remove", params: { ids: [id], confirmed: true, reason: 'Pedido duplicado na importação' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(order.reload.status).to eq('canceled')
    expect(order.snapshot.fetch('removal')).to include('actor_id' => admin.id, 'reason' => 'Pedido duplicado na importação', 'previous_status' => 'draft')
    post "#{url}/remove", params: { ids: [id], confirmed: true, reason: 'Pedido duplicado na importação' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(account.jrc_crm_audit_events.where(event_type: 'order_removed', resource_id: id).count).to eq(1)
    get url, headers: headers
    expect(response.parsed_body.pluck('id')).not_to include(id)
    get "#{url}/#{id}", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'denies agents and cross-account ids without partially removing any selected order' do
    post "#{url}/remove", params: { ids: [order.id], confirmed: true, reason: 'Duplicado' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    other_account = create(:account)
    other_owner = create(:user, account: other_account)
    foreign_order = other_account.jrc_crm_sales_orders.create!(owner: other_owner, status: 'draft', snapshot: {})
    post "#{url}/remove", params: { ids: [order.id, foreign_order.id], confirmed: true, reason: 'Duplicado' }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(order.reload.snapshot).not_to have_key('removal')
  end

  it 'rolls back a whole batch when a financially closed order is included' do
    protected_order = account.jrc_crm_sales_orders.create!(owner: admin, status: 'draft', snapshot: {})
    protected_order.update_columns(status: 'invoiced')
    post "#{url}/remove", params: { ids: [order.id, protected_order.id], confirmed: true, reason: 'Revisão' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload.snapshot).not_to have_key('removal')
    expect(protected_order.reload.status).to eq('invoiced')
    expect(account.jrc_crm_audit_events.where(event_type: 'order_removed')).not_to exist
  end

  it 'protects contracts and even draft invoices without deleting their order or downstream records' do
    invoice = account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current, status: 'draft')
    post "#{url}/remove", params: { ids: [order.id], confirmed: true, reason: 'Revisão' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(invoice.reload.sales_order_id).to eq(order.id)
    expect(order.reload.snapshot).not_to have_key('removal')
  end

  it 'does not allow bypassing the removal endpoint through a normal update' do
    patch "#{url}/#{order.id}", params: { sales_order: { snapshot: { removal: { reason: 'bypass' } } } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(order.reload.snapshot).not_to have_key('removal')
  end
end
