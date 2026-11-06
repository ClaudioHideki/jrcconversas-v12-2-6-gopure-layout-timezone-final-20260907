require 'rails_helper'

RSpec.describe 'First proposal delivery advances the current deal stage', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511998765432', email: 'pessoa@example.test') }
  let(:inbox) { create(:inbox, account: account, name: 'WhatsApp QA', channel: build(:channel_api, account: account)) }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:entry) { pipeline.stages.find_by!(key: 'qualification') }
  let(:target) { pipeline.stages.find_by!(key: 'proposal_sent') }
  let(:deal) { create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: entry, owner: agent, contact: contact) }
  let(:proposal) { JrcCrm::ProposalBuilderService.new(actor: agent, account: account, deal: deal).call }
  let(:headers) { agent.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/proposals/#{proposal.id}/send_proposal" }
  let(:payload) do
    { channel: 'whatsapp', idempotency_key: SecureRandom.uuid,
      delivery: { contact_id: contact.id, inbox_id: inbox.id, content: 'Synthetic proposal delivery' } }
  end

  before do
    account.enable_features!('jrc_crm')
    create(:inbox_member, inbox: inbox, user: agent)
    proposal.proposal_items.create!(name_snapshot: 'Synthetic product', quantity: 1, unit_price_cents: 1000)
  end

  it 'advances the open deal, records its transition and keeps the summary and board consistent' do
    original_value = deal.value_cents
    expect { post url, params: payload, headers: headers, as: :json }.to change(Message, :count).by(1)
    expect(response).to have_http_status(:ok), response.body
    expect(deal.reload).to have_attributes(stage_id: target.id, status: 'open', value_cents: original_value)
    expect(proposal.reload.events.find_by!(event_type: 'sent').metadata.fetch('pipeline_transition')).to include(
      'outcome' => 'advanced', 'deal_id' => deal.id, 'from_stage_id' => entry.id, 'to_stage_id' => target.id
    )
    audit = account.jrc_crm_audit_events.where(resource_type: 'JrcCrm::Deal', resource_id: deal.id, event_type: 'deal_stage_changed')
    expect(audit.count).to eq(1)
    expect(audit.first).to have_attributes(actor_id: agent.id, from_value: entry.id.to_s, to_value: target.id.to_s)
    get "/api/v1/accounts/#{account.id}/crm/dashboard", params: { period: 'all', pipeline_id: pipeline.id }, headers: headers
    row = response.parsed_body.fetch('funnel_stages').find { |s| s['id'] == target.id }
    expect(row).to include('deals_count' => 1, 'value_cents' => original_value, 'pipeline_id' => pipeline.id)
  end

  it 'does not move the deal again on an idempotent replay or a subsequent explicit resend' do
    post url, params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    JrcCrm::DealPipelineService.new(deal: deal.reload, stage: entry, actor: agent).call
    original_messages = Message.count
    post url, params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(Message.count).to eq(original_messages)
    expect(deal.reload.stage_id).to eq(entry.id)
    post url, params: payload.merge(idempotency_key: SecureRandom.uuid), headers: headers, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(Message.count).to eq(original_messages + 1)
    expect(deal.reload.stage_id).to eq(entry.id)
  end

  it 'does not advance or create messages when commercial approval rejects the delivery' do
    proposal.update!(approval_status: 'pending', commercial_approval_status: 'pending')
    expect { post url, params: payload, headers: headers, as: :json }.not_to change(Message, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(deal.reload.stage_id).to eq(entry.id)
    expect(proposal.reload.sent_at).to be_nil
  end

  it 'also advances the first email delivery without creating a second message' do
    email_inbox = create(:inbox, account: account, channel: build(:channel_email, account: account))
    create(:inbox_member, inbox: email_inbox, user: agent)
    conversation = create(:conversation, account: account, inbox: email_inbox, contact: contact, assignee: agent)
    deal.link_conversation!(conversation, agent)
    expect { post url, params: { channel: 'email', idempotency_key: SecureRandom.uuid }, headers: headers, as: :json }
      .to change(Message, :count).by(1)
    expect(response).to have_http_status(:ok), response.body
    expect(deal.reload.stage_id).to eq(target.id)
    expect(proposal.reload.last_sent_conversation_id).to eq(conversation.id)
  end

  it 'does not advance an expired unsent document resent only for historical consultation' do
    proposal.update!(valid_until: Date.yesterday)
    expect { post url, params: payload.merge(historical: true), headers: headers, as: :json }.to change(Message, :count).by(1)
    expect(response).to have_http_status(:ok), response.body
    expect(deal.reload.stage_id).to eq(entry.id)
    expect(proposal.reload.sent_at).to be_nil
    expect(proposal.events.find_by!(event_type: 'historical_resent').metadata['pipeline_transition']).to be_nil
  end
end
