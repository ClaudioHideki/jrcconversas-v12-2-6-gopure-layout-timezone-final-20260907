require 'rails_helper'

RSpec.describe 'Commercial orders, contacts and isolation', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { admin.create_new_auth_token }
  let(:contact) { create(:contact, account: account) }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  before { account.enable_features!('jrc_crm') }

  it 'keeps direct 100x20 and monthly 30 financials identical in preview, save, reload and PDF' do
    scenarios = [
      { billing: 'one_time', quantity: 100, price: 2000, initial: 200_000, mrr: 0, contract: nil, pdf: 'R$ 2.000,00' },
      { billing: 'monthly', quantity: 1, price: 3000, initial: 0, mrr: 3000, contract: 36_000, pdf: 'R$ 360,00' }
    ]
    scenarios.each do |scenario|
      product = create(:jrc_crm_product, account: account, sku: scenario[:billing], billing_model: scenario[:billing],
        unit_price_cents: scenario[:price], setup_fee_cents: 0, contract_term_months: 12, requires_implementation: false)
      payload = { sales_order: { contact_id: contact.id, status: 'pending', items: [
        { product_id: product.id, quantity: scenario[:quantity], unit_cents: scenario[:price] }
      ] } }
      expected = { 'total_cents' => scenario[:initial], 'monthly_cents' => scenario[:mrr] }
      post "#{base}/crm/sales_orders/preview", headers: headers, as: :json, params: payload
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected.merge('contract_total_cents' => scenario[:contract]))
      post "#{base}/crm/sales_orders", headers: headers, as: :json, params: payload
      expect(response).to have_http_status(:created)
      id = response.parsed_body.fetch('id')
      expect(response.parsed_body).to include(expected)
      expect(JrcCrm::SalesOrder.find(id).implementation_items).to be_empty
      get "#{base}/crm/sales_orders/#{id}", headers: headers
      expect(response.parsed_body).to include(expected)
      get "#{base}/crm/sales_orders/#{id}/pdf", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to include(scenario[:pdf])
      File.binwrite(Rails.root.join("tmp/r3-#{scenario[:billing]}.pdf"), response.body) if ENV['CRM_QA_ARTIFACTS'] == '1'
    end
  end

  it 'exposes the configured CRM theme without exposing arbitrary account attributes' do
    account.update!(custom_attributes: { crm_theme: 'gopure', internal_config: 'private-value' })
    get base, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('custom_attributes', 'crm_theme')).to eq('gopure')
    expect(response.parsed_body.fetch('custom_attributes')).not_to have_key('internal_config')
  end

  it 'saves financial adjustments, reopens unchanged and rejects forged totals' do
    post "#{base}/crm/sales_orders", headers: headers, as: :json, params: { sales_order: {
      contact_id: contact.id, status: 'pending', shipping_cents: 10_000, discount_cents: 20_000,
      total_cents: 1, snapshot: { taxes_percent: 10, surcharge_cents: 500 },
      items: [{ name: 'Produto', quantity: 100, unit_cents: 2500, snapshot: { billing_model: 'one_time' } }]
    } }
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch('id')
    expect(response.parsed_body).to include('total_cents' => 264_500, 'monthly_cents' => 0)
    get "#{base}/crm/sales_orders/#{id}", headers: headers
    expect(response.parsed_body).to include('total_cents' => 264_500, 'shipping_cents' => 10_000, 'discount_cents' => 20_000)
    patch "#{base}/crm/sales_orders/#{id}", headers: headers, as: :json, params: { sales_order: { total_cents: 1 } }
    expect(response.parsed_body['total_cents']).to eq(264_500)
  end

  it 'rejects products from another account without leaving partial orders' do
    foreign = create(:jrc_crm_product)
    expect do
      post "#{base}/crm/sales_orders", headers: headers, as: :json, params: { sales_order: {
        contact_id: contact.id, items: [{ product_id: foreign.id, name: 'Foreign', quantity: 1, unit_cents: 100 }]
      } }
    end.not_to change(JrcCrm::SalesOrder, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'allows an agent to add and complete an activity on their direct order' do
    agent_headers = agent.create_new_auth_token
    post "#{base}/crm/sales_orders", headers: agent_headers, as: :json, params: { sales_order: {
      contact_id: contact.id, items: [{ name: 'Produto', quantity: 100, unit_cents: 2000 }]
    } }
    expect(response).to have_http_status(:created)
    order_id = response.parsed_body.fetch('id')
    post "#{base}/crm/activities", headers: agent_headers, as: :json, params: { activity: {
      sales_order_id: order_id, title: 'Retorno', activity_type: 'follow_up', due_at: 1.day.from_now.iso8601
    } }
    expect(response).to have_http_status(:created)
    id = response.parsed_body.fetch('id')
    post "#{base}/crm/activities/#{id}/complete", headers: agent_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['completed_at']).to be_present
  end

  it 'denies administrative product and pipeline creation to agents' do
    post "#{base}/crm/products", headers: agent.create_new_auth_token, as: :json, params: { product: { name: 'Denied' } }
    expect(response).to have_http_status(:unauthorized)
    post "#{base}/crm/pipelines", headers: agent.create_new_auth_token, as: :json, params: { pipeline: { name: 'Denied', key: 'denied' } }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'finds a contact beyond page one with accurate identity and account scope' do
    create_list(:contact, 18, account: account)
    found = create(:contact, account: account, name: 'Zzz Cliente Global', phone_number: '+5511999998877')
    create(:contact, name: 'Zzz Cliente Global', phone_number: '+5511999998877')
    get "#{base}/contacts/search", headers: headers, params: { q: 'Cliente Global', page: 1 }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq([found.id])
    expect(response.parsed_body['payload'].first['phone_number']).to eq(found.phone_number)
  end

  it 'filters company membership and label groups before paginating' do
    person = create(:contact, :with_email, account: account)
    company = create(:contact, :with_email, account: account, additional_attributes: { company_name: 'Empresa Teste' })
    company.add_labels(['grupo comercial'])
    get "#{base}/contacts", headers: headers, params: { relationship: 'companies' }
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq([company.id])
    get "#{base}/contacts", headers: headers, params: { relationship: 'people' }
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq([person.id])
    get "#{base}/contacts", headers: headers, params: { relationship: 'groups' }
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq([company.id])
  end
  it 'paginates filtered contacts across the entire account and returns real summary values' do
    people = create_list(:contact, 18, :with_email, account: account, name: 'Pessoa paginada')
    create(:contact, :with_email, account: account, additional_attributes: { company_name: 'Empresa' })
    get "#{base}/contacts", headers: headers, params: { relationship: 'people', page: 2, include_relationship_summary: true }
    expect(response.parsed_body.dig('meta', 'count')).to eq(18)
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq(people.last(3).map(&:id))
    expect(response.parsed_body.dig('meta', 'relationship_statistics', 'total')).to eq(19)
    get "#{base}/contacts/search", headers: headers, params: { q: 'Pessoa', relationship: 'people', page: 2 }
    expect(response.parsed_body.dig('meta', 'count')).to eq(18)
    expect(response.parsed_body.dig('meta', 'has_more')).to be(false)
    expect(response.parsed_body['payload'].length).to eq(3)
  end

  it 'filters ownership and duplicate candidates without crossing accounts or merging records' do
    owned = create(:contact, :with_email, account: account)
    unassigned = create(:contact, :with_email, account: account, phone_number: '+5511987654321')
    duplicate = create(:contact, :with_email, account: account)
    duplicate.update_column(:phone_number, '+55 (11) 98765-4321')
    create(:contact, phone_number: '+5511987654321')
    create(:jrc_crm_lead, account: account, owner: admin, contact: owned)
    get "#{base}/contacts", headers: headers, params: { relationship: 'unassigned' }
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to contain_exactly(unassigned.id, duplicate.id)
    get "#{base}/contacts", headers: headers, params: { owner_id: admin.id, include_relationship_summary: true }
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to eq([owned.id])
    expect(response.parsed_body['payload'].first['crm_owners']).to eq([{ 'id' => admin.id, 'name' => admin.name }])
    expect do
      get "#{base}/contacts", headers: headers, params: { relationship: 'duplicates' }
    end.not_to change(Contact, :count)
    expect(response.parsed_body['payload'].map { |row| row['id'] }).to contain_exactly(unassigned.id, duplicate.id)
  end

  it 'requires implementation details only for configured items and preserves them after approval' do
    product = create(:jrc_crm_product, account: account, billing_model: 'monthly', requires_implementation: true,
                       unit_price_cents: 3900, setup_fee_cents: 5000, contract_term_months: 12)
    items = [{ product_id: product.id, quantity: 20, unit_cents: 3900 },
             { name: 'Físico', quantity: 100, unit_cents: 2000, snapshot: { billing_model: 'one_time' } }]
    expect do
      post "#{base}/crm/sales_orders", headers: headers, as: :json,
           params: { sales_order: { contact_id: contact.id, status: 'pending', items: items } }
    end.not_to change(JrcCrm::SalesOrder, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    items[0][:snapshot] = { implementation_owner: admin.name, implementation_date: Date.tomorrow.iso8601 }
    post "#{base}/crm/sales_orders", headers: headers, as: :json,
         params: { sales_order: { contact_id: contact.id, status: 'approved', items: items } }
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('total_cents' => 300_000, 'monthly_cents' => 78_000)
    order = JrcCrm::SalesOrder.find(response.parsed_body['id'])
    expect(order.backoffice_requests.sole.metadata['implementation_item_ids']).to eq([order.order_items.find_by!(product: product).id])
    expect(order.snapshot['contract_total_cents']).to eq(1_236_000)
  end

  it 'keeps product recurrence and implementation independent and does not invent a term' do
    %w[monthly one_time].each_with_index do |billing, index|
      post "#{base}/crm/products", headers: headers, as: :json, params: { product: {
        name: "Produto #{billing}", sku: "NEW-#{index}", billing_model: billing, unit_price_cents: 2000,
        requires_implementation: index == 1, contract_term_months: nil
      } }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('requires_implementation' => (index == 1), 'contract_term_months' => nil)
    end
  end

  it 'blocks foreign and other-agent orders, activity assignment and customer mismatches' do
    owned = account.jrc_crm_sales_orders.create!(owner: admin, contact: contact)
    other = create(:account)
    foreign_user = create(:user, account: other)
    foreign = other.jrc_crm_sales_orders.create!(owner: foreign_user)
    agent_headers = agent.create_new_auth_token
    [owned, foreign].each do |order|
      get "#{base}/crm/sales_orders/#{order.id}", headers: agent_headers
      expect(response).to have_http_status(:not_found)
      post "#{base}/crm/activities", headers: agent_headers, as: :json,
           params: { activity: { sales_order_id: order.id, title: 'Denied', activity_type: 'task' } }
      expect(response).to have_http_status(:not_found)
    end
    post "#{base}/crm/activities", headers: headers, as: :json,
         params: { activity: { sales_order_id: owned.id, user_id: foreign_user.id, title: 'Denied', activity_type: 'task' } }
    expect(response).to have_http_status(:not_found)
  end

  it 'allows administrator funnel CRUD and reorder but refuses deletion in use or foreign stages' do
    post "#{base}/crm/pipelines", headers: headers, as: :json, params: { pipeline: { name: 'Novo Funil', key: 'novo' } }
    expect(response).to have_http_status(:created)
    pipeline = account.jrc_crm_pipelines.find(response.parsed_body['id'])
    stages = [1, 2].map { |position| create(:jrc_crm_stage, account: account, pipeline: pipeline, position: position) }
    post "#{base}/crm/stages/reorder", headers: headers, as: :json,
         params: { stages: [{ id: stages[1].id, position: 1 }, { id: stages[0].id, position: 2 }] }
    expect(response).to have_http_status(:ok)
    expect(pipeline.stages.reload.map(&:id)).to eq(stages.reverse.map(&:id))
    deal = create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: stages[0], owner: admin)
    delete "#{base}/crm/stages/#{stages[0].id}", headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    delete "#{base}/crm/pipelines/#{pipeline.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(deal.reload.stage_id).to eq(stages[0].id)
    other = create(:account)
    other_pipeline = create(:jrc_crm_pipeline, account: other)
    foreign = create(:jrc_crm_stage, account: other, pipeline: other_pipeline)
    post "#{base}/crm/stages/reorder", headers: headers, as: :json, params: { stages: [{ id: foreign.id, position: 1 }] }
    expect(response).to have_http_status(:not_found)
  end

  it 'persists, reloads and edits a mixed order without mixing recurring and initial values' do
    post "#{base}/crm/sales_orders", headers: headers, as: :json, params: { sales_order: {
      contact_id: contact.id, status: 'pending', items: [
        { name: 'Produto físico', quantity: 100, unit_cents: 2000, snapshot: { billing_model: 'one_time' } },
        { name: 'Ramais', quantity: 20, unit_cents: 3900, snapshot: { billing_model: 'monthly', setup_fee_cents: 5000 } },
        { name: 'Consultoria', quantity: 5, unit_cents: 15000, snapshot: { billing_model: 'one_time' } }
      ]
    } }
    expect(response).to have_http_status(:created)
    order = response.parsed_body
    expect(order).to include('total_cents' => 375_000, 'monthly_cents' => 78_000)
    expect(order.dig('snapshot', 'contract_total_cents')).to be_nil
    get "#{base}/crm/sales_orders/#{order['id']}", headers: headers
    expect(response.parsed_body).to include('total_cents' => 375_000, 'monthly_cents' => 78_000)
    patch "#{base}/crm/sales_orders/#{order['id']}", headers: headers, as: :json, params: { sales_order: {
      discount_cents: 20000, shipping_cents: 10000, snapshot: { discount_percent: nil, taxes_percent: 10, surcharge_cents: 500 }
    } }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('total_cents' => 402_000, 'monthly_cents' => 78_000)
    expect(response.parsed_body.dig('snapshot', 'installments').sum { |row| row['value'] }).to eq(402_000)
  end

  it 'refuses forged implementation flags and preserves existing items after a failed update' do
    product = create(:jrc_crm_product, account: account, requires_implementation: true)
    post "#{base}/crm/sales_orders", headers: headers, as: :json, params: { sales_order: {
      contact_id: contact.id, status: 'draft', items: [{ product_id: product.id, quantity: 1, unit_cents: 2000,
                                                       snapshot: { requires_implementation: false } }]
    } }
    expect(response).to have_http_status(:created)
    order = response.parsed_body
    expect(order['items'].first.dig('snapshot', 'requires_implementation')).to be(true)
    patch "#{base}/crm/sales_orders/#{order['id']}", headers: headers, as: :json,
          params: { sales_order: { status: 'pending', items: order['items'] } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JrcCrm::SalesOrder.find(order['id'])).to be_draft
    expect(JrcCrm::SalesOrder.find(order['id']).order_items.count).to eq(1)
  end

  it 'rejects fractional reorder positions and collisions with untouched stages without changing data' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stages = [1, 2, 3].map { |position| create(:jrc_crm_stage, account: account, pipeline: pipeline, position: position) }
    [1.5, '2invalid', 0, 3].each do |position|
      post "#{base}/crm/stages/reorder", headers: headers, as: :json,
           params: { stages: [{ id: stages[0].id, position: position }] }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(stages.map { |stage| stage.reload.position }).to eq([1, 2, 3])
    end
  end

end
