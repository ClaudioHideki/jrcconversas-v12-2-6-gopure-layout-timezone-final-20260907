require 'rails_helper'

RSpec.describe 'Contact pagination and search', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { agent.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/contacts" }

  it 'reaches all 94 contacts without repeats, including tied sort values, and allows going back' do
    contacts = create_list(:contact, 94, :with_email, account: account, name: 'Busca teste', last_activity_at: nil)
    seen = []
    (1..7).each do |page|
      get url, params: { page: page, sort: 'last_activity_at' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('meta', 'count')).to eq(94)
      seen.concat(response.parsed_body['payload'].pluck('id'))
    end
    expect(seen.size).to eq(94)
    expect(seen).to match_array(contacts.map(&:id))
    get url, params: { page: 1, sort: 'last_activity_at' }, headers: headers
    expect(response.parsed_body['payload'].pluck('id')).to eq(seen.first(15))
  end

  it 'provides further search results until has_more is false' do
    contacts = create_list(:contact, 31, account: account, name: 'Busca teste')
    seen = []
    (1..3).each do |page|
      get "#{url}/search", params: { q: 'Busca teste', page: page, sort: 'name' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('meta', 'has_more')).to eq(page < 3)
      seen.concat(response.parsed_body['payload'].pluck('id'))
    end
    expect(seen).to match_array(contacts.map(&:id))
  end
  it 'treats missing, zero, negative and malformed pages as the first page' do
    contact = create(:contact, account: account, name: 'Busca segura')
    [nil, 0, -4, 'invalid'].each do |page|
      get "#{url}/search", params: { q: 'Busca segura', page: page }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])
    end
  end

end
