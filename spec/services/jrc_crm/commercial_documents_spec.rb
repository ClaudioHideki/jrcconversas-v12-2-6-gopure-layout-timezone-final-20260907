require 'rails_helper'

RSpec.describe 'Commercial order calculations and documents' do
  let(:account) { create(:account, name: 'Outra Empresa') }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, :with_email, account: account) }

  it 'converts a recurring proposal once using the same initial amount as the accepted quote' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: owner, contact: contact, pipeline: pipeline, stage: stage)
    proposal = create(:jrc_crm_proposal, account: account, owner: owner, deal: deal, issuer_company_name: account.name)
    product = create(:jrc_crm_product, account: account, billing_model: 'monthly', contract_term_months: 12)
    proposal.proposal_items.create!(product: product, name_snapshot: 'Ramal', billing_model: 'monthly',
                                    quantity: 20, unit_price_cents: 3900, setup_fee_cents: 5000)
    proposal.update_columns(status: 'accepted', sent_at: 1.hour.ago, accepted_at: Time.current)
    previous_proposal_total = proposal.reload.total_cents
    service = JrcCrm::ProposalToOrderService.new(proposal: proposal, actor: owner)
    order = service.call
    expect(order.reload).to have_attributes(total_cents: previous_proposal_total, monthly_cents: 78_000)
    expect(order.total_cents).to eq(83_000)
    expect(service.call.id).to eq(order.id)
    expect(proposal.reload.total_cents).to eq(previous_proposal_total)
    expect(order.snapshot['company_name']).to eq(account.name)
  end

  it 'includes every item and financial adjustment in the PDF without applying another tenant identity' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact, shipping_cents: 10_000, discount_cents: 20_000,
      products_cents: 250_000, total_cents: 264_500,
      snapshot: { financial_version: 2, company_name: account.name, taxes_cents: 24_000, taxes_percent: 10, surcharge_cents: 500 })
    10.times do |index|
      order.order_items.create!(name: "Produto #{index + 1}", quantity: 10, unit_cents: 2500,
                               one_time_cents: 25_000, snapshot: { billing_model: 'one_time' })
    end
    expect(order.financial_summary[:total_cents]).to eq(264_500)
    pdf = JrcCrm::OrderPdfService.new(order).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Produto 10', 'TOTAL INICIAL', 'R$ 2.645,00', 'R$ 100,00', 'R$ 5,00', account.name)
    expect(text).not_to include('GoPure', 'Implantação e entrega')
    expect(text.scan('/Type /Page ').length).to be > 1
    File.binwrite(Rails.root.join('tmp/commercial-order-qa.pdf'), pdf) if ENV['CRM_QA_ARTIFACTS'] == '1'
  end

  it 'preserves unspecified legacy products rather than assigning recurring or implementation flags' do
    product = create(:jrc_crm_product, account: account, contract_term_months: 12, integrations: [])
    expect(product.reload.contract_term_months).to eq(12)
    expect(product.requires_implementation).to be(false)
    order = account.jrc_crm_sales_orders.create!(owner: owner, total_cents: 12_345, monthly_cents: 4000)
    order.update!(notes: 'Sem alteração financeira')
    expect(order.reload).to have_attributes(total_cents: 12_345, monthly_cents: 4000)
  end
  it 'keeps long order notes above signatures and footers' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact,
      notes: (1..120).map { |i| "Linha #{i}: condicao comercial." }.join("\n"), snapshot: {financial_version: 2})
    pdf = JrcCrm::OrderPdfService.new(order).call
    expect(pdf).to include('Linha 120:')
    coordinates = pdf.scan(/BT \/F[12] [\d.]+ Tf [\d.-]+ ([\d.-]+) Td/).flatten.map(&:to_f)
    expect(coordinates).to all(be >= 30)
  end

  it 'escapes PDF literal backslashes as well as parentheses' do
    page = JrcCrm::CommercialPdf::Document::Page.new
    page.text(44, 100, 'C:\\clientes (teste)')
    expect(page.commands).to include("C:\\\\clientes \\(teste\\)")
  end

  it 'honors the account branding opt-out even when its name is GoPure' do
    account.update!(name: 'GoPure', custom_attributes: {'crm_theme' => 'default'})
    service = Object.new.extend(JrcCrm::CommercialDocumentBrand)
    expect(service.send(:document_gopure?, account)).to be(false)
  end

  it 'renders all contract items and separates initial amounts from MRR' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact, status: 'approved',
      products_cents: 34_000, total_cents: 34_000, monthly_cents: 8500,
      snapshot: { financial_version: 2, company_name: account.name })
    contract = account.jrc_crm_contracts.create!(owner: owner, contact: contact, sales_order: order,
                                                one_time_cents: 34_000, monthly_cents: 8500)
    17.times { |i| contract.contract_items.create!(name: "Item #{i + 1}", quantity: 2, one_time_cents: 2000, monthly_cents: 500) }
    pdf = JrcCrm::ContractPdfService.new(contract).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Item 17', 'INICIAL', 'R$ 20,00', 'R$ 5,00', account.name)
    expect(text).not_to include('GoPure')
  end

  it 'renders a long proposal under its own account identity without off-page acceptance text' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: owner, contact: contact, pipeline: pipeline, stage: stage)
    notes = (1..120).map { |i| "Linha #{i}: condicao comercial." }.join("\n")
    proposal = create(:jrc_crm_proposal, account: account, owner: owner, deal: deal,
                                        issuer_company_name: account.name, solution_description: notes, commercial_notes: notes)
    pdf = JrcCrm::ProposalPdfService.new(proposal).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Linha 120:', account.name, 'Condi')
    expect(text).not_to include('GoPure')
    coordinates = pdf.scan(/BT \/F[12] [\d.]+ Tf [\d.-]+ ([\d.-]+) Td/).flatten.map(&:to_f)
    expect(coordinates).to all(be >= 30)
  end

  it 'reads the saved initial and recurring amounts of a GoPure r5 order without repricing it' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact,
      products_cents: 100_000, total_cents: 100_000, monthly_cents: 78_000,
      snapshot: { financial_version: 2, contracted_recurring_cents: 936_000, contract_total_cents: 1_036_000 })
    order.order_items.create!(name: 'Ramal legado', quantity: 20, unit_cents: 3900,
      one_time_cents: 100_000, recurring_cents: 78_000,
      snapshot: { billing_model: 'monthly', setup_fee_cents: 5000, contract_term_months: 12 })
    expect(order.financial_summary).to include(total_cents: 100_000, monthly_cents: 78_000,
      contracted_recurring_cents: 936_000, contract_total_cents: 1_036_000, legacy_gopure_terms: true)
    expect(JrcCrm::OrderPdfService.new(order).call).to include('1.000,00')
    expect(order.reload).to have_attributes(total_cents: 100_000, monthly_cents: 78_000)
  end

end
