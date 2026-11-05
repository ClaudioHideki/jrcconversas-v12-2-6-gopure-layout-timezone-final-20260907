require 'rails_helper'

RSpec.describe 'GoPure commercial approval', type: :request do
  let(:account) { create(:account, name: 'GoPure') }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:other_admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:proposal) { JrcCrm::ProposalBuilderService.new(account: account, actor: agent, contact: contact).call }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/proposals/#{proposal.id}" }
  before { account.enable_features!('jrc_crm') }

  it 'requires commercial approval even without discounts and does not send before approval' do
    expect do
      JrcCrm::ProposalDeliveryService.new(proposal: proposal, actor: agent).call
    end.to raise_error(ArgumentError, /aprovações internas/)
    expect(account.messages.count).to eq(0)
  end

  it 'renders one-time public terms without an implicit term, monthly summary or default notes' do
    proposal.update!(status: 'sent', sent_at: Time.current, approval_status: 'approved', commercial_approval_status: 'approved')
    get "/jrc/propostas/#{account.id}/#{proposal.public_token}", params: { preview: true }
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css('.meta').text).not_to include('Vigência')
    expect(document.css('.summary').text).not_to include('Recorrência mensal')
    expect(document.css('.cards .label').map(&:text)).not_to include('Mensalidade')
    expect(document.css('.summary .total').text).to include('Valor total da proposta')
    expect(document.css('.conditions').text).not_to include('Renovação', 'Multa de cancelamento')
    expect(response.body).not_to include(JrcCrm::ProposalBuilderService::DEFAULT_COMMERCIAL_NOTES)
  end

  it 'infers a manually entered recurring amount instead of discarding it because of the old checkbox flag' do
    expect(proposal.has_monthly_fee).to be(false)
    patch url, headers: agent.create_new_auth_token, as: :json, params: { proposal: { monthly_cents: 3500, has_monthly_fee: false } }
    expect(response).to have_http_status(:ok)
    expect(proposal.reload).to have_attributes(has_monthly_fee: true, monthly_cents: 3500, total_cents: 3500)
  end

  it 'allows an authorized administrator to approve and audits the decision, retaining the native commercial gate' do
    proposal.proposal_items.create!(name_snapshot: 'Produto', billing_model: 'one_time', quantity: 1, unit_price_cents: 1000)
    post "#{url}/request_approval", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(proposal.reload).to have_attributes(financial_approval_status: 'not_required', technical_approval_status: 'not_required')
    post "#{url}/approve", params: { approval_type: 'commercial', decision: 'approved' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(proposal.reload).to have_attributes(approval_status: 'approved', commercial_approval_status: 'approved')
    expect(proposal.events.where(event_type: 'approval_updated', user_id: admin.id)).to exist
    expect(JrcApprovals::CommercialGate).to receive(:check!).with(resource: proposal, user: agent, key: 'crm.proposal_send')
      .and_raise(JrcApprovals::Error, 'APPROVAL_REQUIRED')
    expect { JrcCrm::ProposalDeliveryService.new(proposal: proposal, actor: agent).call }.to raise_error(JrcApprovals::Error)
  end

  it 'denies agent approval and self-approval, and keeps prior decisions intact' do
    post "#{url}/approve", params: { approval_type: 'commercial', decision: 'approved' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    proposal.update!(owner: admin)
    post "#{url}/approve", params: { approval_type: 'commercial', decision: 'approved' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(proposal.reload.commercial_approval_status).to eq('pending')
    post "#{url}/approve", params: { approval_type: 'commercial', decision: 'approved' }, headers: other_admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
  end
end
