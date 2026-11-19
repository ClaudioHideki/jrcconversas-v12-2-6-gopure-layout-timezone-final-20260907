require 'rails_helper'

RSpec.describe 'CRM product actions', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:contact) { create(:contact, account: account) }
  let(:product) { create(:jrc_crm_product, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/products/#{product.id}" }

  before { account.enable_features!('jrc_crm') }

  it 'updates a product and returns the saved values' do
    patch url, headers: headers, params: { product: { name: 'Reviewed synthetic product', unit_price_cents: 5990 } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(product.reload).to have_attributes(name: 'Reviewed synthetic product', unit_price_cents: 5990)
  end

  it 'deletes an unused product permanently' do
    product
    expect { delete url, headers: headers }.to change(JrcCrm::Product, :count).by(-1)
    expect(response).to have_http_status(:no_content)
  end

  it 'preserves proposal item snapshots when the native product reference is removed' do
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: admin, contact: contact).call
    item = proposal.proposal_items.create!(product: product, name_snapshot: 'Historical product', quantity: 1, unit_price_cents: 5990)
    delete url, headers: headers
    expect(response).to have_http_status(:no_content)
    expect(item.reload).to have_attributes(product_id: nil, name_snapshot: 'Historical product', unit_price_cents: 5990)
  end

  it 'rejects protected order links without deleting the product or changing proposal snapshots' do
    order = JrcCrm::SalesOrder.create!(account: account, owner: admin, source_type: 'manual', status: 'draft', order_number: 'SYNTHETIC-DELETE')
    order_item = order.order_items.create!(product: product, name: product.name, quantity: 1, unit_cents: 5990)
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: admin, contact: contact).call
    item = proposal.proposal_items.create!(product: product, name_snapshot: product.name, quantity: 1, unit_price_cents: 5990)
    expect { delete url, headers: headers }.not_to change(JrcCrm::Product, :count)
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['code']).to eq('PRODUCT_HAS_DEPENDENCIES')
    expect([item.reload.product_id, order_item.reload.product_id]).to eq([product.id, product.id])
  end

  it 'keeps activation independent from deletion' do
    patch "#{url}/toggle_active", headers: headers
    expect(response).to have_http_status(:ok)
    expect(product.reload.active).to be(false)
  end

  it 'rejects deletion by an agent' do
    agent = create(:user, account: account, role: :agent)
    delete url, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
    expect(JrcCrm::Product.exists?(product.id)).to be(true)
  end

  it 'does not delete a product from another account' do
    foreign = create(:jrc_crm_product)
    delete "/api/v1/accounts/#{account.id}/crm/products/#{foreign.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(JrcCrm::Product.exists?(foreign.id)).to be(true)
  end
end
