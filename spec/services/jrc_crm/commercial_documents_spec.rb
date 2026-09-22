require 'rails_helper'

RSpec.describe 'Commercial order calculations and documents' do
  let(:account) { create(:account, name: 'Outra Empresa') }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, :with_email, account: account) }

  it 'converts a recurring proposal using quantity and initial fees without charging the first month twice' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: owner, contact: contact, pipeline: pipeline, stage: stage)
    proposal = create(:jrc_crm_proposal, account: account, owner: owner, deal: deal, status: 'accepted')
    product = create(:jrc_crm_product, account: account, billing_model: 'monthly', contract_term_months: 12)
    proposal.proposal_items.create!(product: product, name_snapshot: 'Ramal', billing_model: 'monthly',
                                    quantity: 20, unit_price_cents: 3900, setup_fee_cents: 5000)
    previous_proposal_total = proposal.reload.total_cents
    service = JrcCrm::ProposalToOrderService.new(proposal: proposal, actor: owner)
    order = service.call
    expect(order.reload).to have_attributes(total_cents: 100_000, monthly_cents: 78_000)
    expect(order.snapshot).to include('contracted_recurring_cents' => 936_000, 'contract_total_cents' => 1_036_000)
    expect(service.call.id).to eq(order.id)
    expect(proposal.reload.total_cents).to eq(previous_proposal_total)
    expect(order.snapshot['company_name']).to eq(account.name)
  end

  it 'includes every item and financial adjustment in the PDF without applying another tenant identity' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact, shipping_cents: 10_000, discount_cents: 20_000,
                                               snapshot: { taxes_percent: 10, surcharge_cents: 500 })
    10.times do |index|
      order.order_items.create!(name: "Produto #{index + 1}", quantity: 10, unit_cents: 2500,
                               one_time_cents: 25_000, snapshot: { billing_model: 'one_time' })
    end
    JrcCrm::OrderFinancials.recalculate!(order)
    expect(order.total_cents).to eq(264_500)
    pdf = JrcCrm::OrderPdfService.new(order).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Produto 10', 'VALOR INICIAL', 'R$ 2.645,00', 'R$ 100,00', 'R$ 5,00', 'OUTRA EMPRESA')
    expect(text).not_to include('GoPure', 'Implantação e entrega')
    expect(text).to include('/Count 4')
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
    page = JrcCrm::ProposalPdfService::Page.new
    expect(page.send(:escape, 'C:\\clientes (teste)')).to eq("C:\\\\clientes \\(teste\\)")
  end

  it 'honors the account branding opt-out even when its name is GoPure' do
    account.update!(name: 'GoPure', custom_attributes: {'crm_theme' => 'default'})
    service = Object.new.extend(JrcCrm::CommercialDocumentBrand)
    expect(service.send(:document_gopure?, account)).to be(false)
  end

  it 'renders all contract items and separates initial amounts from MRR' do
    order = account.jrc_crm_sales_orders.create!(owner: owner, contact: contact, snapshot: {financial_version: 2})
    contract = account.jrc_crm_contracts.create!(owner: owner, contact: contact, sales_order: order,
                                                one_time_cents: 34_000, monthly_cents: 8500)
    17.times { |i| contract.contract_items.create!(name: "Item #{i + 1}", quantity: 2, one_time_cents: 2000, monthly_cents: 500) }
    pdf = JrcCrm::ContractPdfService.new(contract).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Item 17', 'INICIAL', 'MRR', 'R$ 20,00', 'R$ 5,00', 'OUTRA EMPRESA')
    expect(text).not_to include('GoPure')
  end

  it 'renders a long proposal under its own account identity without off-page acceptance text' do
    pipeline = create(:jrc_crm_pipeline, account: account)
    stage = create(:jrc_crm_stage, account: account, pipeline: pipeline)
    deal = create(:jrc_crm_deal, account: account, owner: owner, contact: contact, pipeline: pipeline, stage: stage)
    notes = (1..120).map { |i| "Linha #{i}: condicao comercial." }.join("\n")
    proposal = create(:jrc_crm_proposal, account: account, owner: owner, deal: deal,
                                        solution_description: notes, commercial_notes: notes)
    pdf = JrcCrm::ProposalPdfService.new(proposal).call
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    expect(text).to include('Linha 120:', 'OUTRA EMPRESA', 'Aceite comercial')
    expect(text).not_to include('GoPure')
    coordinates = pdf.scan(/BT \/F[12] [\d.]+ Tf [\d.-]+ ([\d.-]+) Td/).flatten.map(&:to_f)
    expect(coordinates).to all(be >= 30)
  end

end
