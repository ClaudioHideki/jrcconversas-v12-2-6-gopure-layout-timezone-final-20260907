require 'rails_helper'
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe 'Contact to CRM lead integration', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { agent.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/leads" }
  let(:contact) { create(:contact, account: account, name: 'Thiago Ribeiro', email: 'thiago@example.test', phone_number: '+5511987654321') }

  before { account.enable_features!('jrc_crm') }

  it 'uses the selected contact ID, returns its lead and prevents repeated creation' do
    get "#{url}/for_contact", params: { contact_id: contact.id }, headers: headers
    expect(response.parsed_body).to eq('linked' => false, 'lead_id' => nil)

    expect do
      post url, params: { lead: { name: contact.name, contact_id: contact.id } }, headers: headers, as: :json
    end.to change(JrcCrm::Lead, :count).by(1).and not_change(Contact, :count)
    expect(response).to have_http_status(:created)
    lead_id = response.parsed_body['id']
    expect(response.parsed_body['contact_id']).to eq(contact.id)

    post url, params: { lead: { name: contact.name, contact_id: contact.id } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['id']).to eq(lead_id)

    get "#{url}/for_contact", params: { contact_id: contact.id }, headers: headers
    expect(response.parsed_body).to eq('linked' => true, 'lead_id' => lead_id)
  end

  it 'creates a Contact and Lead together and exposes the contact in the central list' do
    expect do
      post url, params: { lead: { name: 'Pessoa nova', email: '  NOVA@example.test ', phone: '+55 (11) 98888-7777',
                                  company_name: 'Empresa teste', source: 'Central', notes: 'Interesse comercial' } }, headers: headers, as: :json
    end.to change(Contact, :count).by(1).and change(JrcCrm::Lead, :count).by(1)
    expect(response).to have_http_status(:created)
    person = account.contacts.find(response.parsed_body['contact_id'])
    expect(person.email).to eq('nova@example.test')
    expect(person.phone_number).to eq('+5511988887777')
    expect(person.additional_attributes['company_name']).to eq('Empresa teste')

    get "/api/v1/accounts/#{account.id}/contacts", headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to include(person.id)
  end

  it 'reuses a contact by normalized phone without overwriting its name or email' do
    contact
    expect do
      post url, params: { lead: { name: 'Nome comercial', phone: '+55 (11) 98765-4321' } }, headers: headers, as: :json
    end.not_to change(Contact, :count)
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['contact_id']).to eq(contact.id)
    expect(contact.reload.name).to eq('Thiago Ribeiro')
    expect(contact.email).to eq('thiago@example.test')
  end

  it 'reuses a contact by case insensitive email' do
    contact
    expect do
      post url, params: { lead: { name: 'Thiago', email: 'THIAGO@example.test' } }, headers: headers, as: :json
    end.not_to change(Contact, :count)
    expect(response.parsed_body['contact_id']).to eq(contact.id)
  end

  it 'reuses the existing account-scoped identifier' do
    contact.update!(identifier: 'cliente-141')
    post url, params: { lead: { name: contact.name, identifier: 'cliente-141' } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['contact_id']).to eq(contact.id)
  end

  it 'rolls back a newly created contact when the lead is invalid' do
    foreign_owner = create(:user)
    expect do
      post url, params: { lead: { name: 'Rollback', email: 'rollback@example.test', owner_id: foreign_owner.id } },
                headers: admin.create_new_auth_token, as: :json
    end.to not_change(Contact, :count).and not_change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['errors']).to be_present
  end

  it 'does not create a contact for an invalid explicit contact ID' do
    expect do
      post url, params: { lead: { name: 'Invalid', contact_id: 0, email: 'invalid@example.test' } }, headers: headers, as: :json
    end.not_to change(Contact, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects a selected contact from another account' do
    other = create(:contact)
    post url, params: { lead: { name: other.name, contact_id: other.id } }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
    get "#{url}/for_contact", params: { contact_id: other.id }, headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'does not merge conflicting email and phone identities' do
    other = create(:contact, :with_email, account: account)
    expect do
      post url, params: { lead: { name: 'Conflito', email: other.email, phone: contact.phone_number } }, headers: headers, as: :json
    end.not_to change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['errors'].join).to include('contatos diferentes')
  end

  it 'does not leak another agent lead or create a duplicate for it' do
    lead = create(:jrc_crm_lead, account: account, owner: admin, contact: contact)
    get "#{url}/for_contact", params: { contact_id: contact.id }, headers: headers
    expect(response.parsed_body).to eq('linked' => true, 'lead_id' => nil)
    expect do
      post url, params: { lead: { name: contact.name, contact_id: contact.id } }, headers: headers, as: :json
    end.not_to change(JrcCrm::Lead, :count)
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.keys).to eq(['errors'])
    get "#{url}/for_contact", params: { contact_id: contact.id }, headers: admin.create_new_auth_token
    expect(response.parsed_body['lead_id']).to eq(lead.id)
  end

  it 'keeps existing leads linked even after conversion or discard' do
    lead = create(:jrc_crm_lead, account: account, owner: agent, contact: contact, status: :converted)
    post url, params: { lead: { name: contact.name, contact_id: contact.id } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['id']).to eq(lead.id)
  end

  it 'ignores an agent owner override and allows an administrator to assign an account member' do
    post url, params: { lead: { name: contact.name, contact_id: contact.id, owner_id: admin.id } }, headers: headers, as: :json
    expect(response.parsed_body.dig('owner', 'id')).to eq(agent.id)
    other = create(:contact, account: account)
    post url, params: { lead: { name: other.name, contact_id: other.id, owner_id: agent.id } }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('owner', 'id')).to eq(agent.id)
  end

  it 'blocks CRM entry points when the account feature is disabled' do
    account.disable_features!('jrc_crm')
    post url, params: { lead: { name: 'Disabled', email: 'disabled@example.test' } }, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    get "#{url}/for_contact", params: { contact_id: contact.id }, headers: headers
    expect(response).to have_http_status(:forbidden)
  end

  it 'asks for identification instead of creating an invisible, unidentifiable contact' do
    expect do
      post url, params: { lead: { name: 'Sem identificação' } }, headers: headers, as: :json
    end.not_to change(Contact, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
