require 'rails_helper'

RSpec.describe 'Sales opportunities from conversations', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/sales/opportunities" }
  let(:payload) do
    { opportunity: { contact_id: conversation.contact_id, conversation_display_id: conversation.display_id,
                     title: 'Venda', product_name: 'Produto', value: '1000', temperature: 'hot',
                     owner_id: '', team_id: '', notes: 'Teste completo', idempotency_key: 'conversation-qa' } }
  end

  before do
    account.enable_features!('sales', 'jrc_crm')
    create(:inbox_member, inbox: conversation.inbox, user: agent)
  end

  it 'creates an opportunity, links the conversation and schedules its next activity' do
    post url, params: payload, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    data = response.parsed_body
    expect(data).to include('conversation_id' => conversation.id, 'conversation_display_id' => conversation.display_id)
    expect(data.dig('owner', 'id')).to eq(agent.id)
    post "#{url}/#{data['id']}/activities", params: { activity: {
      activity_type: 'task', title: 'Venda', scheduled_at: '2026-09-23T10:25', status: 'scheduled'
    } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(SalesOpportunity.find(data['id']).sales_activities.count).to eq(1)
    expect { post url, params: payload, headers: headers, as: :json }.not_to change(SalesOpportunity, :count)
    expect(response).to have_http_status(:ok)
  end

  it 'does not accept a conversation from another account' do
    other = create(:conversation)
    payload[:opportunity].delete(:conversation_display_id)
    payload[:opportunity][:conversation_id] = other.id
    expect { post url, params: payload, headers: headers, as: :json }.not_to change(SalesOpportunity, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'does not accept a conversation the agent cannot access' do
    other = create(:conversation, account: account)
    payload[:opportunity].merge!(conversation_display_id: other.display_id, contact_id: other.contact_id)
    expect { post url, params: payload, headers: headers, as: :json }.not_to change(SalesOpportunity, :count)
    expect(response).to have_http_status(:unauthorized)
  end
end
