account = Account.order(:id).first
user = User.find_by(email: 'john@acme.inc') || User.order(:id).first

if account
  account.update!(name: 'GoPure', locale: 'pt_BR')
  account.enable_features!('jrc_crm', 'jrc_campaigns', 'sales')
  JrcCrm::DefaultPipelineService.new(account: account).perform if defined?(JrcCrm::DefaultPipelineService)
end

if user
  user.update!(name: 'Admin GoPure', email: 'admin@gopure.com.br')
end

puts({
  account_id: account&.id,
  account_name: account&.name,
  crm_enabled: account&.feature_enabled?('jrc_crm'),
  campaigns_enabled: account&.feature_enabled?('jrc_campaigns'),
  admin_email: user&.email
}.inspect)
