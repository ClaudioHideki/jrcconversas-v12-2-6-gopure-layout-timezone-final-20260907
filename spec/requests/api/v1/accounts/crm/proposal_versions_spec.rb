require 'rails_helper'

RSpec.describe 'CRM proposal versions and historical delivery', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }
  let(:contact) { create(:contact, account: account, company_id: company.id, phone_number: '+5511998765432', email: 'fixture@example.test') }
  let(:company) { account.master_companies.create!(name: 'Version fixture') }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp fixture', channel: build(:channel_api, account: account)) }
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox, assignee: agent) }
  let(:proposal) { JrcCrm::ProposalBuilderService.new(account: account, company: company, contact: contact, actor: agent).call }
  let(:product) { JrcCrm::Product.create!(account: account, name: 'Original service', sku: 'VERSION-TEST', unit_price_cents: 20_000) }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/proposals/#{proposal.id}" }
  let(:public_url) { "/jrc/propostas/#{account.id}/#{proposal.public_token}" }

  before do
    account.enable_features!('jrc_crm', 'jrc_customer_master')
    conversation
    create(:inbox_member, inbox: inbox, user: agent)
    proposal.proposal_items.create!(product: product, name_snapshot: product.name, quantity: 2, unit_price_cents: 20_000)
  end

  # Native send: PDF, message builder and events run; no provider or real worker consumes messages.
  def send_original
    post "#{url}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    proposal.reload
  end

  it 'keeps normal current proposals and their public HTML/PDF usable' do
    send_original
    expect(proposal.status).to eq('sent')
    expect(proposal.events.find_by!(event_type: 'sent').document).to be_attached
    get public_url
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Aceitar proposta')
    get "#{public_url}/pdf"
    expect(response).to have_http_status(:ok)
    expect(response.body).to start_with('%PDF-')
  end

  it 'resends an expired PDF exactly, without reactivating or rewriting the proposal' do
    send_original
    original = Message.find(proposal.last_sent_message_id).attachments.first.file.download
    travel 40.days
    before = proposal.reload.attributes
    post "#{url}/send_proposal", params: { channel: 'whatsapp', historical: true }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(proposal.reload.attributes).to eq(before)
    event = proposal.events.find_by!(event_type: 'historical_resent')
    message = Message.find(event.metadata['message_id'])
    expect(message.attachments.first.file.download).to eq(original)
    expect(message.content).to include('SEM VIGÊNCIA', '/jrc/propostas-historicas/')
    expect(proposal.customer_response_allowed?).to be(false)
  end

  it 'exposes the unchanged PDF through a read-only link while rejecting acceptance on the expired original' do
    send_original
    original = Message.find(proposal.last_sent_message_id).attachments.first.file.download
    travel 40.days
    post "#{url}/send_proposal", params: { channel: 'whatsapp', historical: true }, headers: headers, as: :json
    event = proposal.events.find_by!(event_type: 'historical_resent')
    get event.metadata['public_url']
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Documento histórico')
    expect(response.body).not_to include('<form', 'Aceitar proposta')
    get "#{event.metadata['public_url']}/pdf"
    expect(response.body).to eq(original)
    post "#{public_url}/accept", params: { accepted_by_name: 'Fixture', accepted_by_document: 'synthetic' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.accepted_at).to be_nil
    travel_back
  end

  %w[accepted rejected canceled].each do |status|
    it "allows an authorized historical resend of #{status}, retaining the closed state" do
      send_original
      proposal.update!(status: status)
      before = proposal.attributes
      post "#{url}/send_proposal", params: { channel: 'whatsapp', historical: true }, headers: headers, as: :json
      expect(response).to have_http_status(:ok), response.body
      expect(proposal.reload.attributes).to eq(before)
      expect(proposal.events.where(event_type: 'historical_resent').count).to eq(1)
      expect(proposal.sales_orders.count).to eq(0)
    end
  end

  it 'uses the native email conversation for a historical resend and preserves the original PDF' do
    send_original
    email_inbox = create(:inbox, account: account, channel: build(:channel_email, account: account))
    email_conversation = create(:conversation, account: account, contact: contact, inbox: email_inbox)
    proposal.update!(status: 'canceled')
    post "#{url}/send_proposal", params: { channel: 'email', historical: true }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    event = proposal.events.find_by!(event_type: 'historical_resent')
    expect(event.metadata['conversation_id']).to eq(email_conversation.id)
    expect(Message.find(event.metadata['message_id']).content).to include('SEM VIGÊNCIA')
  end

  it 'retains original approvals and blocks historical sends while approval is pending' do
    proposal.update!(valid_until: Date.yesterday, approval_status: 'pending', commercial_approval_status: 'pending')
    expect do
      post "#{url}/send_proposal", params: { channel: 'whatsapp', historical: true }, headers: headers, as: :json
    end.not_to change(Message, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.approval_status).to eq('pending')
  end

  it 'copies all commercial data and items into an editable draft, preserving source and PDF' do
    send_original
    original = proposal.attributes
    post "#{url}/duplicate", headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
    revised = JrcCrm::Proposal.find(response.parsed_body['id'])
    expect(revised).to have_attributes(status: 'draft', version_number: 2, contact_id: proposal.contact_id,
                                       commercial_notes: proposal.commercial_notes, valid_until: proposal.valid_until)
    expect(revised.proposal_items.first.attributes.except('id', 'proposal_id', 'created_at', 'updated_at')).to eq(
      proposal.proposal_items.first.attributes.except('id', 'proposal_id', 'created_at', 'updated_at')
    )
    expect(revised.public_token).not_to eq(proposal.public_token)
    expect(revised.sent_at).to be_nil
    expect(revised.accepted_by_document).to be_nil
    expect(proposal.reload.attributes).to eq(original)
  end

  it 'locks the previous version and retains its original document after creating a revision' do
    send_original
    original = proposal.attributes
    pdf = Message.find(proposal.last_sent_message_id).attachments.first.file.download
    post "#{url}/duplicate", headers: headers, as: :json
    expect(proposal.reload.attributes).to eq(original)
    expect(proposal.locked_for_editing?).to be(true)
    expect(proposal.public_availability[:available]).to be(false)
    expect(JrcCrm::ProposalDocumentArchive.new(proposal).blob.download).to eq(pdf)
    patch "#{url}/items/#{proposal.proposal_items.first.id}", params: { item: { quantity: 99 } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'edits the copied draft and lists version changes without editing the original' do
    send_original
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    patch "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}",
          params: { proposal: { commercial_notes: 'Revised fixture', valid_until: Date.current + 25 } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(proposal.reload.commercial_notes).not_to eq('Revised fixture')
    expect(revised.reload.commercial_notes).to eq('Revised fixture')
    get "#{url}/version_history", headers: headers
    expect(response.parsed_body.map { |version| version['id'] }).to eq([proposal.id, revised.id])
    expect(response.parsed_body.first['events'].map { |event| event['type'] }).to include('version_created', 'sent')
  end

  it 'allocates monotonically increasing versions even when the same ancestor is revised twice' do
    post "#{url}/duplicate", headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
    post "#{url}/duplicate", headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
    expect(response.parsed_body['version_number']).to eq(3)
    get "#{url}/version_history", headers: headers
    expect(response.parsed_body.map { |version| version['version_number'] }).to eq([1, 2, 3])
  end

  it 'does not let a historical token authorize acceptance, cross-account access or indefinite public access' do
    send_original
    proposal.update!(status: 'canceled')
    post "#{url}/prepare_historical", headers: headers, as: :json
    historical_url = response.parsed_body.fetch('public_url')
    token = historical_url.split('/').last
    post "/jrc/propostas/#{account.id}/#{token}/accept", params: { accepted_by_name: 'Fixture', accepted_by_document: 'synthetic' }
    expect(response).to have_http_status(:not_found)
    get historical_url.sub("/#{account.id}/", "/#{account.id + 1}/")
    expect(response).to have_http_status(:not_found)
    travel 8.days
    get historical_url
    expect(response).to have_http_status(:not_found)
    expect(proposal.reload.status).to eq('canceled')
    travel_back
  end

  it 'hides other owners and accounts from version creation, resend, preparation and history' do
    other = create(:user, account: account, role: :agent)
    %w[duplicate prepare_historical].each do |action|
      post "#{url}/#{action}", headers: other.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
    get "#{url}/version_history", headers: other.create_new_auth_token
    expect(response).to have_http_status(:not_found)
    outsider = create(:user, account: create(:account), role: :administrator)
    post "#{url}/send_proposal", params: { channel: 'whatsapp', historical: true }, headers: outsider.create_new_auth_token, as: :json
    expect(response).not_to have_http_status(:ok)
    expect(proposal.events.where(event_type: 'historical_resent').count).to eq(0)
  end

  it 'never reconstructs a previously sent historical PDF when its original document was lost' do
    proposal.update!(status: 'canceled', sent_at: 5.days.ago)
    expect do
      post "#{url}/prepare_historical", headers: headers, as: :json
    end.not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['errors'].join).to include('PDF original')
  end

  it 'still permits a new editable version when a legacy PDF is missing, auditing its absence honestly' do
    proposal.update!(status: 'canceled', sent_at: 5.days.ago)
    post "#{url}/duplicate", headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
    expect(response.parsed_body['status']).to eq('draft')
    expect(JrcCrm::ProposalDocumentArchive.new(proposal).blob).to be_nil
    expect(proposal.events.exists?(event_type: 'document_unavailable')).to be(true)
    get "#{url}/version_history", headers: headers
    expect(response.parsed_body.first['document_available']).to be(false)
  end

  it 'saves new quantities, prices, freight and validity only on the new version and generates a new live PDF' do
    send_original
    old_attributes = proposal.attributes
    old_pdf = Message.find(proposal.last_sent_message_id).attachments.first.file.download
    travel 40.days
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    next_url = "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}"
    patch next_url, params: { proposal: { valid_until: Date.current + 20, shipping_mode: 'separate', shipping_cents: 1500,
                                          payment_condition: 'installments', installments_count: 3, commercial_notes: 'New terms' } },
                    headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    patch "#{next_url}/items/#{revised.proposal_items.first.id}", params: { item: { quantity: 3, unit_price_cents: 25_000 } },
                                                                  headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(revised.reload).to have_attributes(shipping_cents: 1500, installments_count: 3, commercial_notes: 'New terms')
    post "#{next_url}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    get "/jrc/propostas/#{account.id}/#{revised.reload.public_token}/pdf"
    expect(response.body).to start_with('%PDF-')
    expect(response.body).not_to eq(old_pdf)
    expect(proposal.reload.attributes).to eq(old_attributes)
  end

  it 'requires commercial approval again when prices or discounts change on a copied proposal' do
    send_original
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    next_url = "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}"
    patch next_url, params: { proposal: { discount_cents: 15_000 } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(revised.reload.approval_status).to eq('not_required')
    expect do
      post "#{next_url}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    end.not_to change(Message, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{next_url}/request_approval", headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(revised.reload.approval_status).to eq('pending')
    expect(proposal.reload.approval_status).to eq('not_required')
  end

  it 'replays a selected-recipient historical delivery without another message or changing the source' do
    send_original
    proposal.update!(status: 'canceled')
    post "#{url}/prepare_historical", headers: headers, as: :json
    link = response.parsed_body.fetch('public_url')
    payload = { historical: true, historical_url: link, channel: 'whatsapp', idempotency_key: SecureRandom.uuid,
                delivery: { contact_id: contact.id, inbox_id: inbox.id, content: "Original document: #{link}" } }
    post "#{url}/send_proposal", params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    counts = [Message.count, ActiveStorage::Blob.count, proposal.events.count]
    post "#{url}/send_proposal", params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect([Message.count, ActiveStorage::Blob.count, proposal.events.count]).to eq(counts)
    expect(proposal.reload.status).to eq('canceled')
  end

  it 'rejects a historical URL signed for a different proposal before sending anything' do
    send_original
    proposal.update!(status: 'canceled')
    other = JrcCrm::ProposalBuilderService.new(account: account, company: company, actor: agent).call
    link = JrcCrm::HistoricalProposalLink.url(other, base_url: 'http://www.example.com')
    expect do
      post "#{url}/send_proposal", params: { historical: true, historical_url: link, channel: 'whatsapp' }, headers: headers, as: :json
    end.not_to change(Message, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.status).to eq('canceled')
  end

  it 'does not mutate an expired original through direct commercial update requests' do
    send_original
    travel 40.days
    attributes = proposal.reload.attributes
    patch url, params: { proposal: { valid_until: Date.current + 10, discount_cents: 1 } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.attributes).to eq(attributes)
    post "#{url}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.attributes).to eq(attributes)
  end

  it 'protects an expired unsent original while allowing its new draft to correct the inherited validity' do
    proposal.update!(valid_until: Date.yesterday)
    patch url, params: { proposal: { valid_until: Date.current + 10 } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    expect(revised.locked_for_editing?).to be(false)
    patch "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}", params: { proposal: { valid_until: Date.current + 10 } },
                                                                        headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(proposal.reload.valid_until).to eq(Date.yesterday)
  end

  it 'edits recurring products and quantities only in the new version using the existing item rules' do
    send_original
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    monthly = JrcCrm::Product.create!(account: account, name: 'Monthly fixture', sku: 'MONTHLY-REV', billing_model: 'monthly',
                                      unit_price_cents: 30_000)
    post "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}/items",
         params: { item: { product_id: monthly.id, quantity: 2, unit_price_cents: 30_000 } }, headers: headers, as: :json
    expect(response).to have_http_status(:created), response.body
    expect(revised.reload.monthly_cents).to eq(60_000)
    expect(revised.proposal_items.count).to eq(2)
    expect(proposal.reload.monthly_cents).to eq(0)
    expect(proposal.proposal_items.count).to eq(1)
  end

  it 'accepts a newly sent live version but not the superseded source, without transferring acceptance between versions' do
    send_original
    post "#{url}/duplicate", headers: headers, as: :json
    revised = JrcCrm::Proposal.find(response.parsed_body.fetch('id'))
    post "/api/v1/accounts/#{account.id}/crm/proposals/#{revised.id}/send_proposal", params: { channel: 'whatsapp' }, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    signer = { accepted_by_name: 'Fixture signer', accepted_by_document: 'synthetic-document' }
    post "#{public_url}/accept", params: signer
    expect(response).to have_http_status(:unprocessable_entity)
    post "/jrc/propostas/#{account.id}/#{revised.reload.public_token}/accept", params: signer
    expect(response).to have_http_status(:redirect)
    expect([proposal.reload.status, revised.reload.status, proposal.sales_orders.count, revised.sales_orders.count]).to eq(['sent', 'accepted', 0, 1])
  end
end
