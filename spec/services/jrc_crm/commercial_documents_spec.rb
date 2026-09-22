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
    text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8)
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
end
