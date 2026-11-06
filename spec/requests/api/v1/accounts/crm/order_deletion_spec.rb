require 'rails_helper'

RSpec.describe 'Administrative order deletion with retention', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:order) do
    account.jrc_crm_sales_orders.create!(owner: agent, created_by: agent, contact: contact,
                                         source_type: 'manual', order_origin: 'direct_sale', status: 'pending', total_cents: 1000, snapshot: {})
  end
  let(:url) { "/api/v1/accounts/#{account.id}/crm/sales_orders" }
  let(:headers) { admin.create_new_auth_token }
  let(:service) { JrcCrm::OrderDeletionService.new(account: account, actor: admin, ids: [order.id], reason: 'Cadastro duplicado QA') }

  before { account.enable_features!('jrc_crm') }

  it 'previews the actual internal approval and performs a physical deletion with a retained receipt' do
    approval_id = order.backoffice_requests.find_by!(request_kind: 'approval').id
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'backoffice', id: approval_id, action: 'delete'))
    expect(order.reload).to be_pending
    result = service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(result[:removed_ids]).to eq([order.id])
    expect(JrcCrm::SalesOrder.exists?(order.id)).to be(false)
    expect(JrcCrm::BackofficeRequest.exists?(approval_id)).to be(false)
    receipt = JrcCrm::AuditEvent.find(result[:receipt_ids].first)
    expect(receipt.metadata).to include('reason' => 'Cadastro duplicado QA', 'total_cents' => 1000, 'order_number' => order.order_number)
    get "#{url.sub('/sales_orders', '')}/dashboard", params: { period: 'all' }, headers: headers
    expect(response.parsed_body.dig('commercial_summary', 'orders', 'total_count')).to eq(0)
  end

  it 'removes unissued financial drafts, unsigned contract drafts and forecast commissions in dependency order' do
    order.update!(status: 'approved', approval_authorized: true)
    contract = order.contracts.create!(account: account, owner: agent, contact: contact, status: 'draft')
    invoice = account.jrc_crm_invoices.create!(sales_order: order, contract: contract, due_on: Date.current + 10, total_cents: 1000)
    commission = order.commissions.create!(account: account, user: agent, status: 'forecast')
    plan = service.preview
    expect(plan[:rows].select do |r|
      %w[contracts invoices commissions].include?(r[:type])
    end.map { |r| r[:action] }).to eq(%w[delete delete delete]), plan[:rows].to_json
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(JrcCrm::Invoice.exists?(invoice.id)).to be(false)
    expect(JrcCrm::Contract.exists?(contract.id)).to be(false)
    expect(JrcCrm::SalesCommission.exists?(commission.id)).to be(false)
  end

  it 'recalculates active-order revenue after a permitted physical deletion without altering the customer' do
    order.update!(status: 'approved', approval_authorized: true)
    original_customer = contact.reload.attributes
    get "#{url.sub('/sales_orders', '')}/dashboard", params: { period: 'all' }, headers: headers
    expect(response.parsed_body.dig('commercial_summary', 'orders', 'revenue_cents')).to eq(1000)
    plan = service.preview
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    get "#{url.sub('/sales_orders', '')}/dashboard", params: { period: 'all' }, headers: headers
    expect(response.parsed_body.dig('commercial_summary', 'orders', 'revenue_cents')).to eq(0)
    expect(response.parsed_body.dig('commercial_summary', 'orders', 'active_count')).to eq(0)
    expect(contact.reload.attributes).to eq(original_customer)
  end

  it 'retains processed payments even when reconciliation is pending and requests a real cancellation review' do
    invoice = account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current + 10, total_cents: 1000, balance_cents: 600, status: 'issued')
    payment = account.jrc_crm_payments.create!(invoice: invoice, amount_cents: 400, paid_at: Time.current, reconciliation_status: 'pending')
    before = [invoice.attributes, payment.attributes]
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'payments', id: payment.id, action: 'preserve'))
    result = service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(result[:removed_ids]).to be_empty
    expect(result[:retained_ids]).to eq([order.id])
    expect([invoice.reload.attributes, payment.reload.attributes]).to eq(before)
    request = order.backoffice_requests.find(result[:cancellation_request_ids].first)
    expect(request).to have_attributes(request_kind: 'cancellation', status: 'pending')
    expect(request.metadata['external_reversal_executed']).to be(false)
    expect(order.reload.status).to eq('pending')
  end

  it 'does not delete signed contracts, signed files or their source order' do
    order.update!(status: 'approved', approval_authorized: true)
    contract = order.contracts.create!(account: account, owner: agent, contact: contact, status: 'draft')
    contract.signed_document.attach(io: StringIO.new('%PDF-QA'), filename: 'signed.pdf', content_type: 'application/pdf')
    contract.update!(signature_status: 'signed', signed_at: Time.current, signed_by_name: 'Synthetic signer')
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'contracts', id: contract.id, action: 'preserve'))
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(contract.reload.signature_status).to eq('signed')
    expect(contract.signed_document).to be_attached
    expect(order.reload.status).to eq('approved')
  end

  it 'retains a draft carrying fiscal or external collection evidence' do
    invoice = account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current + 10, snapshot: { nfe: { access_key: 'QA-ONLY' } })
    expect(service.preview[:rows]).to include(hash_including(type: 'invoices', id: invoice.id, action: 'preserve'))
  end

  it 'rejects stale previews without partially deleting anything' do
    plan = service.preview
    account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current + 10)
    expect { service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    expect(order.reload).to be_pending
    expect(order.backoffice_requests.count).to eq(1)
    expect(account.jrc_crm_audit_events.where(event_type: 'order_deletion_executed')).to be_empty
  end

  it 'requires an administrator at both HTTP endpoints and does not expose foreign orders' do
    post "#{url}/deletion_preview", params: { ids: [order.id], reason: 'Duplicado QA' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    foreign = create(:account)
    foreign_order = foreign.jrc_crm_sales_orders.create!(owner: create(:user, account: foreign), source_type: 'manual', order_origin: 'direct_sale',
                                                         status: 'draft')
    post "#{url}/deletion_preview", params: { ids: [foreign_order.id], reason: 'Duplicado QA' }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    post "#{url}/delete_with_dependencies", params: { ids: [order.id], reason: 'Duplicado QA', confirmed: true },
                                            headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'binds the preview to its actor, reason and exact scope and requires a typed confirmation' do
    plan = service.preview
    expect { service.execute(token: plan[:token], confirmed: true, confirmation: 'EXCLUIR') }.to raise_error(JrcCrm::OrderDeletionService::Conflict)
    changed_service = JrcCrm::OrderDeletionService.new(account: account, actor: admin, ids: [order.id], reason: 'Outro motivo')
    expect do
      changed_service.execute(token: plan[:token], confirmed: true,
                              confirmation: plan[:confirmation])
    end.to raise_error(JrcCrm::OrderDeletionService::Conflict)
    expect(order.reload).to be_pending
  end

  it 'preserves completed activities and their order' do
    activity = order.activities.create!(account: account, user: agent, activity_type: 'task', title: 'Scheduled synthetic work')
    activity.update!(status: 'completed', completed_at: Time.current)
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'activities', id: activity.id, action: 'preserve'))
    expect(plan[:rows]).to include(hash_including(type: 'orders', id: order.id, action: 'preserve'))
  end

  it 'validates reason and does not mutate data during preview' do
    order
    post "#{url}/deletion_preview", params: { ids: [order.id], reason: '' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect { post "#{url}/deletion_preview", params: { ids: [order.id], reason: 'Duplicado QA' }, headers: headers, as: :json }
      .not_to change(JrcCrm::AuditEvent, :count)
    expect(response).to have_http_status(:ok)
  end

  it 'executes the real HTTP confirmation and rejects a duplicate submission' do
    post "#{url}/deletion_preview", params: { ids: [order.id], reason: 'Duplicado QA' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    plan = response.parsed_body
    payload = { ids: [order.id], reason: 'Duplicado QA', confirmed: true, confirmation: plan['confirmation'], preview_token: plan['token'] }
    post "#{url}/delete_with_dependencies", params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(response.parsed_body['removed_ids']).to eq([order.id])
    count = account.jrc_crm_audit_events.where(event_type: 'order_deletion_executed').count
    post "#{url}/delete_with_dependencies", params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(account.jrc_crm_audit_events.where(event_type: 'order_deletion_executed').count).to eq(count)
  end

  it 'rejects expired previews and tokens issued to another administrator' do
    plan = service.preview
    other_admin = create(:user, account: account, role: :administrator)
    other_service = JrcCrm::OrderDeletionService.new(account: account, actor: other_admin, ids: [order.id], reason: 'Cadastro duplicado QA')
    expect { other_service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    travel_to 11.minutes.from_now do
      expect { service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
        .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    end
    expect(order.reload).to be_pending
  end

  it 'rechecks administrative authority at confirmation after a role revocation' do
    plan = service.preview
    account.account_users.find_by!(user: admin).update!(role: 'agent')
    expect { service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect(order.reload).to be_pending
    expect(account.jrc_crm_audit_events.where(event_type: 'order_deletion_executed')).to be_empty
  end

  it 'rejects a preview when a processed payment is added before confirmation' do
    invoice = account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current + 10, total_cents: 1000)
    plan = service.preview
    payment = account.jrc_crm_payments.create!(invoice: invoice, amount_cents: 1000, paid_at: Time.current)
    expect { service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    expect(payment.reload.invoice_id).to eq(invoice.id)
    expect(order.reload).to be_pending
  end

  it 'rolls back the entire batch and its receipts when a deletion fails' do
    second = account.jrc_crm_sales_orders.create!(owner: admin, status: 'draft')
    batch = JrcCrm::OrderDeletionService.new(account: account, actor: admin, ids: [order.id, second.id], reason: 'Duplicado QA')
    plan = batch.preview
    allow_any_instance_of(JrcCrm::SalesOrder).to receive(:destroy!).and_wrap_original do |method, *args|
      raise ActiveRecord::RecordNotDestroyed if method.receiver.id == second.id

      method.call(*args)
    end
    expect { batch.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    expect(JrcCrm::SalesOrder.where(id: [order.id, second.id]).count).to eq(2)
    expect(order.backoffice_requests.count).to eq(1)
    expect(account.jrc_crm_audit_events.where(event_type: 'order_deletion_executed')).to be_empty
  end

  it 'does not delete a scheduled activity linked from Relationship by a real foreign key' do
    activity = order.activities.create!(account: account, user: agent, activity_type: 'task', title: 'Synthetic appointment')
    assignment = JrcRelationship::Assignment.create!(account: account, contact: contact, owner: agent, status: 'active')
    action = JrcRelationship::Action.create!(account: account, assignment: assignment, activity: activity,
                                             kind: 'follow_up', reason: 'Synthetic work', source_key: 'qa-only', status: 'open', priority: 10)
    plan = service.preview
    expect(plan[:blocked]).to be(true)
    expect(plan[:issues].join).to include('jrc_relationship_actions')
    expect { service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation]) }
      .to raise_error(JrcCrm::OrderDeletionService::Conflict)
    expect(action.reload.activity_id).to eq(activity.id)
    expect(order.reload).to be_pending
  end

  it 'does not expose or delete orders outside the administrator corporate coverage' do
    company = account.master_companies.create!(name: 'Allowed QA', relationship_type: 'internal')
    blocked_company = account.master_companies.create!(name: 'Blocked QA', relationship_type: 'internal')
    unit = account.jrc_crm_business_units.create!(name: 'Blocked QA', code: 'qa-block', company_id: blocked_company.id)
    JrcCrm::UserBusinessUnit.create!(account: account, user: admin, company: company, scope: 'COMPANY', structure_managed: true)
    order.update!(business_unit: unit)
    post "#{url}/deletion_preview", params: { ids: [order.id], reason: 'Duplicado QA' }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    expect(order.reload).to be_pending
  end

  it 'preserves accepted source proposals, their PDF and history and prevents recreating their deleted order' do
    company = account.master_companies.create!(name: 'Synthetic customer')
    contact.update!(company_id: company.id)
    proposal = JrcCrm::ProposalBuilderService.new(account: account, company: company, contact: contact, actor: admin).call
    product = account.jrc_crm_products.create!(name: 'Synthetic product', sku: 'PURGE-QA', unit_price_cents: 1000)
    proposal.proposal_items.create!(product: product, name_snapshot: product.name, quantity: 1, unit_price_cents: 1000)
    inbox = create(:inbox, account: account, name: 'WhatsApp QA', channel: build(:channel_api, account: account))
    create(:inbox_member, inbox: inbox, user: admin)
    create(:conversation, account: account, contact: contact, inbox: inbox, assignee: admin)
    post "/api/v1/accounts/#{account.id}/crm/proposals/#{proposal.id}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    proposal.reload.update!(status: 'accepted', accepted_at: Time.current)
    event = proposal.events.find_by!(event_type: 'sent')
    original_pdf = event.document.download
    order.update!(proposal: proposal)
    before = proposal.attributes
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'proposals', id: proposal.id, action: 'preserve'))
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(proposal.reload.attributes).to eq(before)
    expect(event.reload.document.download).to eq(original_pdf)
    expect { JrcCrm::ProposalToOrderService.new(proposal: proposal, actor: admin).call }
      .to raise_error(JrcCrm::CommercialFinancials::InvalidTerms, /excluído administrativamente/)
    expect(proposal.sales_orders).to be_empty
  end

  it 'includes metadata-only scheduled followups and deletes their exclusive links' do
    lead = account.jrc_crm_leads.create!(owner: agent, name: 'Synthetic lead')
    activity = account.jrc_crm_activities.create!(user: agent, lead: lead, activity_type: 'task', title: 'Synthetic followup',
                                                  metadata: { sales_order_id: order.id })
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'activities', id: activity.id, action: 'delete'))
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(JrcCrm::Activity.exists?(activity.id)).to be(false)
  end

  it 'retains external charge evidence nested inside arrays and preserves audit history' do
    invoice = account.jrc_crm_invoices.create!(sales_order: order, due_on: Date.current, snapshot: { events: [{ charge_id: 'QA-charge' }] })
    audit = account.jrc_crm_audit_events.create!(actor_type: admin.class.name, actor_id: admin.id, event_type: 'order_created',
                                                 resource_type: order.class.name, resource_id: order.id, metadata: { source: 'synthetic' })
    plan = service.preview
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(invoice.reload.snapshot).to eq('events' => [{ 'charge_id' => 'QA-charge' }])
    expect(audit.reload.metadata).to eq('source' => 'synthetic')
  end

  it 'retains implementation projects and only their corresponding order in a mixed batch' do
    project = JrcProjects::Project.create!(account: account, owner: agent, key: 'QA-PURGE', name: 'Synthetic implementation',
                                           status: 'planned', visibility: 'account', idempotency_key: "crm-order-implementation-#{order.id}")
    second = account.jrc_crm_sales_orders.create!(owner: admin, status: 'draft')
    batch = JrcCrm::OrderDeletionService.new(account: account, actor: admin, ids: [order.id, second.id], reason: 'Duplicado QA')
    plan = batch.preview
    expect(plan[:rows]).to include(hash_including(type: 'projects', id: project.id, action: 'preserve'))
    result = batch.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(result[:removed_ids]).to eq([second.id])
    expect(result[:retained_ids]).to eq([order.id])
    expect(project.reload.status).to eq('planned')
  end

  it 'cancels pending alçadas for deleted resources while retaining decisions and immutable audit' do
    member = account.account_users.find_by!(user: admin)
    policy = JrcApprovals::Policy.create!(account: account, author: member, code: 'QA-DELETE', name: 'Synthetic policy', module_key: 'crm',
                                          event_key: 'order_price')
    version = policy.versions.create!(account: account, publisher: member, version: 1, definition: {}, publication: {}, digest: 'a' * 64)
    request = JrcApprovals::Request.create!(account: account, policy_version: version, requester: member, resource_type: order.class.name,
                                            resource_id: order.id, module_key: 'crm', event_key: 'order_price', request_key: 'qa-delete', input_digest: 'a' * 64,
                                            fingerprint: 'b' * 64, snapshot: {}, stage_plan: [], state: 'returned', expires_at: 1.hour.from_now)
    decision = request.decisions.create!(account: account, actor: member, principal: member, step_code: 'qa-step', decision: 'returned',
                                         reason: 'Synthetic decision', idempotency_key: 'qa-only', payload_digest: 'c' * 64, cycle: 1, expected_version: 0)
    before = decision.attributes
    plan = service.preview
    expect(plan[:rows]).to include(hash_including(type: 'approvals', id: request.id, action: 'cancel'))
    service.execute(token: plan[:token], confirmed: true, confirmation: plan[:confirmation])
    expect(request.reload.state).to eq('canceled')
    expect(decision.reload.attributes).to eq(before)
    expect(JrcApprovals::AuditEvent.where(request_id: request.id, event_type: 'request_canceled')).to exist
    expect { decision.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
