require 'rails_helper'

RSpec.describe 'Registered proposal parties and native contact company links', type: :request do
  let(:account) { create(:account, name: 'GoPure') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:company) { account.master_companies.create!(name: 'Synthetic customer') }
  let(:contact) { create(:contact, account: account, company_id: company.id) }
  let(:issuer) do
    account.master_companies.create!(name: 'Synthetic issuer', relationship_type: 'internal',
                                    tax_id: JrcCrm::ProposalProfile::CONFIG.fetch('gopure').fetch('issuer_tax_id'))
  end
  let(:unit) { account.jrc_crm_business_units.create!(name: 'Synthetic unit', code: 'qa', company_id: issuer.id) }
  let(:proposal) { account.jrc_crm_proposals.create!(owner: admin, contact: contact, company: company, title: 'Draft synthetic') }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:headers) { admin.create_new_auth_token }
  before do
    account.enable_features!('jrc_crm', 'jrc_customer_master')
    JrcCrm::UserBusinessUnit.create!(account: account, user: admin, scope: 'GROUP', structure_managed: true)
  end

  it 'selects an authorized registered issuer independently of the customer and resets commercial approval' do
    proposal.events.create!(account: account, event_type: 'created', description: 'Synthetic QA creation', metadata: { commercial_profile: 'gopure_v1' })
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { business_unit_id: unit.id } }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(proposal.reload).to have_attributes(company_id: company.id, contact_id: contact.id, business_unit_id: unit.id,
      issuer_company_name: issuer.name, commercial_approval_status: 'pending')
    expect(proposal.events.where(event_type: 'updated', user: admin)).to exist
  end

  it 'rejects a foreign issuer, unauthorized corporate unit and changes to a sent document' do
    foreign = create(:account).jrc_crm_business_units.create!(name: 'Foreign', code: 'foreign')
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { business_unit_id: foreign.id } }, headers: headers
    expect(response).to have_http_status(:not_found)
    proposal.update!(sent_at: Time.current, status: 'sent')
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { business_unit_id: unit.id } }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.business_unit_id).to be_nil
  end

  it 'does not switch the commercial approval profile through an issuer change' do
    unrelated_issuer = account.master_companies.create!(name: 'Synthetic other profile', relationship_type: 'internal')
    unrelated_unit = account.jrc_crm_business_units.create!(name: 'Other unit', code: 'other', company_id: unrelated_issuer.id)
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { business_unit_id: unrelated_unit.id } }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.business_unit_id).to be_nil
  end

  it 'allows selecting a registered customer/contact for a direct draft without modifying the contacts' do
    replacement = account.master_companies.create!(name: 'Replacement synthetic')
    person = create(:contact, account: account, company_id: replacement.id)
    original = contact.reload.attributes
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { company_id: replacement.id, contact_id: person.id } }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(proposal.reload).to have_attributes(company_id: replacement.id, contact_id: person.id)
    expect(proposal.events.find_by!(event_type: 'updated').metadata.dig('parties', 'after', 'company_id')).to eq(replacement.id)
    expect(contact.reload.attributes).to eq(original)
    patch "#{base}/crm/proposals/#{proposal.id}", params: { proposal: { company_id: company.id } }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(proposal.reload.company_id).to eq(replacement.id)
  end

  it 'persists the master company in the native contact dialog with audit, without the legacy companies feature' do
    account.disable_features!('companies')
    post "#{base}/contacts", params: { name: 'Synthetic new person', email: 'qa-only@example.invalid', company_id: company.id,
      additional_attributes: { city: 'Test city', company_name: 'Untrusted typed name' } }, headers: headers
    expect(response).to have_http_status(:ok)
    person = account.contacts.find_by!(email: 'qa-only@example.invalid')
    expect(person.company_id).to eq(company.id)
    expect(person.additional_attributes).to include('city' => 'Test city', 'company_name' => company.name)
    expect(account.jrc_crm_audit_events.where(resource_id: person.id, event_type: 'customer_contact_linked')).to exist
    expect { post "#{base}/contacts", params: { name: 'Foreign test', company_id: create(:account).master_companies.create!(name: 'Foreign').id }, headers: headers }
      .not_to change(account.contacts, :count)
    expect(response).to have_http_status(:not_found)
  end
end
