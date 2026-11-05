require 'rails_helper'

RSpec.describe JrcCrm::ProposalProfile do
  let(:account) { create(:account, name: 'GoPure') }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }

  it 'uses centrally configured issuer data and blank notes only for new GoPure proposals' do
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: owner, contact: contact).call
    expect(proposal).to have_attributes(commercial_notes: '', monthly_cents: 0, renewal_type: 'none', cancellation_penalty_percent: 0,
                                       issuer_company_name: 'JRC NUTRITION COMÉRCIO IMPORTAÇÃO E EXPORTAÇÃO LTDA', issuer_tax_id: '52.247.628/0001-90')
    expect(described_class.commercial_only?(proposal)).to be(true)
    requirements = JrcCrm::ProposalApprovalRequirements.new(proposal)
    expect(requirements.commercial?).to be(true)
    expect(requirements.financial?).to be(false)
    expect(requirements.technical?).to be(false)
    proposal.reset_approvals!
    expect(proposal.reload).to have_attributes(approval_status: 'pending', commercial_approval_status: 'pending',
                                              financial_approval_status: 'not_required', technical_approval_status: 'not_required')
  end

  it 'does not rewrite existing notes or issuer data when creating a revision' do
    proposal = create(:jrc_crm_proposal, account: account, owner: owner, deal: nil, contact: contact, commercial_notes: 'Condição anteriormente negociada',
                                       issuer_company_name: 'Emissor histórico', issuer_tax_id: 'documento histórico')
    original = proposal.attributes.except('updated_at', 'lock_version')
    revised = JrcCrm::ProposalRevisionService.new(proposal: proposal, actor: owner).call
    expect(revised).to have_attributes(commercial_notes: proposal.commercial_notes, issuer_company_name: 'Emissor histórico',
                                      issuer_tax_id: 'documento histórico', commercial_approval_status: 'pending')
    expect(proposal.reload.attributes.except('updated_at', 'lock_version')).to eq(original)
    expect(proposal.events.where(event_type: 'document_archived').first.document).to be_attached
  end

  it 'does not apply GoPure commercial rules just because another account uses the green theme' do
    account.update!(name: 'Outra empresa', custom_attributes: { crm_theme: 'gopure' })
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: owner, contact: contact).call
    expect(proposal.commercial_notes).to eq(JrcCrm::ProposalBuilderService::DEFAULT_COMMERCIAL_NOTES)
    expect(described_class.commercial_only?(proposal)).to be(false)
    expect(proposal.issuer_tax_id).not_to eq('52.247.628/0001-90')
  end

  it 'returns the original archived PDF bytes instead of redrawing an issued document' do
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: owner, contact: contact).call
    original = JrcCrm::ProposalDocumentArchive.new(proposal, actor: owner).capture!.download
    expect(JrcCrm::CommercialDocumentService).not_to receive(:new)
    expect(JrcCrm::ProposalPdfService.new(proposal).call).to eq(original)
  end

  it 'infers recurrence from item changes and clears derived charges after removing the last item' do
    proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: owner, contact: contact).call
    expect(proposal.has_monthly_fee).to be(false)
    item = proposal.proposal_items.create!(name_snapshot: 'Item recorrente', billing_model: 'monthly', quantity: 2,
                                           unit_price_cents: 1000, setup_fee_cents: 500)
    expect(proposal.reload).to have_attributes(has_monthly_fee: true, monthly_cents: 2000, total_cents: 2500)
    item.destroy!
    expect(proposal.reload).to have_attributes(has_monthly_fee: false, monthly_cents: 0, implementation_cents: 0, total_cents: 0)
  end

  %w[one_time monthly mixed].each do |billing|
    it "keeps #{billing} classifications and exact totals while removing the PDF monthly summary" do
      proposal = JrcCrm::ProposalBuilderService.new(account: account, actor: owner, contact: contact).call
      modes = billing == 'mixed' ? %w[one_time monthly] : [billing]
      modes.each do |mode|
        proposal.proposal_items.create!(name_snapshot: "Produto #{mode}", billing_model: mode, quantity: 2,
                                        unit_price_cents: 10_000, discount_cents: 500, setup_fee_cents: 1000)
      end
      proposal.recalculate_totals!
      before = proposal.reload.attributes
      pdf = JrcCrm::ProposalPdfService.new(proposal).call
      text = pdf.dup.force_encoding(Encoding::Windows_1252).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      expect(text).not_to include('Recorrência mensal equivalente')
      expect(text).to include(billing == 'one_time' ? 'Valor total da proposta' : 'TOTAL INICIAL')
      expect(pdf.scan(%r{/Type /Page\b}).length).to be <= 2
      expect(proposal.proposal_items.order(:id).pluck(:billing_model)).to eq(modes)
      expect(proposal.reload.attributes).to eq(before)
      expect(proposal.total_cents).to eq(20_500 * modes.length)
      expect(proposal.monthly_cents).to eq(billing == 'one_time' ? 0 : 19_500)
    end
  end
end
