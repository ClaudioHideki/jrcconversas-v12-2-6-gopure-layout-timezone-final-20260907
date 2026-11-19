require 'rails_helper'

RSpec.describe 'Customer master API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:root) { "/api/v1/accounts/#{account.id}/customers" }

  before { account.enable_features!('jrc_customer_master') }

  around do |example|
    original = Rails.application.env_config['action_dispatch.show_exceptions']
    Rails.application.env_config['action_dispatch.show_exceptions'] = :rescuable
    example.run
  ensure
    Rails.application.env_config['action_dispatch.show_exceptions'] = original
  end

  it 'requires authentication' do
    get "#{root}/companies"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'is opt-in for the account' do
    account.disable_features!('jrc_customer_master')
    get "#{root}/companies", headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not list companies of another account' do
    own = account.master_companies.create!(name: 'Own')
    other = create(:account).master_companies.create!(name: 'Private')
    get "#{root}/companies", headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('id')).to include(own.id)
    expect(response.parsed_body['payload'].pluck('id')).not_to include(other.id)
  end

  it 'does not show a company addressed by an ID from another tenant' do
    foreign = create(:account).master_companies.create!(name: 'Private')
    get "#{root}/companies/#{foreign.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'creates a prospect without promoting it to customer' do
    post "#{root}/companies", headers: headers, params: { company: { name: 'Prospect', relationship_type: 'prospect' } }, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('payload', 'relationship_type')).to eq('prospect')
  end

  it 'requires revision on a master company update' do
    own = account.master_companies.create!(name: 'Own')
    patch "#{root}/companies/#{own.id}", headers: headers, params: { company: { name: 'Overwrite' } }, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(own.reload.name).to eq('Own')
  end

  it 'rejects a cross-account contact-company assignment' do
    foreign = create(:account).master_companies.create!(name: 'Private')
    post "#{root}/contacts", headers: headers, params: { contact: { name: 'Cross', company_id: foreign.id } }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'creates the complete contact and company link atomically, preserving profile attributes and audit' do
    account.disable_features!('companies')
    company = account.master_companies.create!(name: 'Empresa de teste')
    attributes = { city: 'São Paulo', country: 'Brazil', country_code: 'BR', description: 'Contato comercial',
                   social_profiles: { linkedin: 'perfil-de-teste' } }
    post "#{root}/contacts", headers: headers, params: { contact: { name: 'Pessoa de teste', email: 'pessoa@example.test',
                                                                    company_id: company.id, additional_attributes: attributes, blocked: true } }, as: :json
    expect(response).to have_http_status(:created)
    contact = account.contacts.find(response.parsed_body.dig('payload', 'id'))
    expect(contact.company_id).to eq(company.id)
    expect(contact.additional_attributes).to include(attributes.deep_stringify_keys)
    expect(contact.blocked).not_to be(true)
    audit = JrcCrm::AuditEvent.find_by!(account: account, resource_type: 'Contact', resource_id: contact.id)
    expect(audit.actor_id).to eq(admin.id)
    expect(audit.to_value['additional_attributes']).to include(attributes.deep_stringify_keys)
    post "#{root}/contacts", headers: headers, params: { contact: { name: 'Duplicado', email: contact.email,
                                                                    company_id: company.id, additional_attributes: { city: 'Não substituir' } } }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body['code']).to eq('POSSIBLE_DUPLICATE')
    expect(account.contacts.where(email: contact.email).count).to eq(1)
    expect(contact.reload.additional_attributes['city']).to eq('São Paulo')
  end

  it 'restricts merges to administrators' do
    agent = create(:user, account: account)
    base = create(:contact, account: account)
    source = create(:contact, account: account)
    post "#{root}/contacts/#{base.id}/merge", headers: agent.create_new_auth_token,
                                              params: { source_contact_id: source.id, confirm: true }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(source.reload).to be_persisted
  end

  it 'refuses merging without explicit confirmation' do
    base = create(:contact, account: account)
    source = create(:contact, account: account)
    post "#{root}/contacts/#{base.id}/merge", headers: headers, params: { source_contact_id: source.id }, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(source.reload).to be_persisted
  end

  it 'saves the complete business address atomically and updates it without replacing other addresses' do
    address = { street: 'Rua Sintética', number: '123', complement: 'Sala 2', district: 'Centro', city: 'Florianópolis',
                state: 'SC', postal_code: '88000-000', country: 'BR' }
    post "#{root}/companies", headers: headers, params: { company: { name: 'Synthetic address company', primary_address: address } }, as: :json
    expect(response).to have_http_status(:created), response.body
    data = response.parsed_body.fetch('payload')
    expect(data['primary_address']).to include(address.stringify_keys)
    company = account.master_companies.find(data['id'])
    other = company.addresses.create!(account: account, address_type: 'billing', street: 'Preserve', country: 'BR')
    patch "#{root}/companies/#{company.id}",
          headers: headers,
          params: { company: { revision: data['revision'], primary_address: address.merge(number: '456') } }, as: :json
    expect(response).to have_http_status(:ok), response.body
    expect(company.addresses.where(address_type: 'business').count).to eq(1)
    expect(response.parsed_body.dig('payload', 'primary_address', 'number')).to eq('456')
    expect(other.reload.street).to eq('Preserve')
  end

  it 'rolls back the new company when its address is invalid' do
    expect do
      post "#{root}/companies",
           headers: headers,
           params: { company: { name: 'Invalid synthetic address', primary_address: { street: 'Rua', country: 'X' * 101 } } }, as: :json
    end.not_to change(JrcCustomers::Company, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
