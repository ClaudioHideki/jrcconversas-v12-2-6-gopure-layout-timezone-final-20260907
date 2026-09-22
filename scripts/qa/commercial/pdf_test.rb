# Isolated checks of the REAL PDF services with in-memory fixtures, not Rails/DB tests.
# Logos are deliberately excluded here; verify MiniMagick/logo integration in Rails CI.
require_relative 'standalone_support'
require 'ostruct'
begin
  require 'mini_magick'
rescue LoadError
  $LOADED_FEATURES << 'mini_magick.rb'
end
root = File.expand_path('../../..', __dir__)
require "#{root}/app/services/jrc_crm/commercial_document_brand" if File.exist?("#{root}/app/services/jrc_crm/commercial_document_brand.rb")
require "#{root}/app/services/jrc_crm/proposal_pdf_service"
require "#{root}/app/services/jrc_crm/order_pdf_service"
require "#{root}/app/services/jrc_crm/contract_pdf_service"

module StandalonePdfFormatting
  def logo_data = nil
  def money(cents)
    whole, fraction = cents.to_i.divmod(100)
    "R$ #{whole.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse},#{format('%02d', fraction)}"
  end
end
class AuditOrderPdf < JrcCrm::OrderPdfService
  prepend StandalonePdfFormatting
end
class AuditProposalPdf < JrcCrm::ProposalPdfService
  prepend StandalonePdfFormatting
end
class AuditContractPdf < JrcCrm::ContractPdfService
  prepend StandalonePdfFormatting
end

module CommercialPdfFixtures
  def item(index)
    OpenStruct.new(name: "Item #{index.to_s.rjust(3, '0')}", name_snapshot: "Item #{index.to_s.rjust(3, '0')}", quantity: 2,
                   unit_cents: 1000, unit_price_cents: 1000, one_time_cents: 2000, recurring_cents: 2000,
                   monthly_cents: 2000, snapshot: { 'contract_term_months' => 12 }, description_snapshot: '',
                   included_quantity: 0, included_unit: '', billing_model: 'monthly', setup_fee_cents: 1000,
                   applied_discount_cents: 0, initial_total_cents: 2000)
  end
  def account = OpenStruct.new(name: 'Empresa Independente', custom_attributes: {})
  def owner = OpenStruct.new(name: 'Responsavel Comercial')
  def contact = OpenStruct.new(name: 'Cliente Teste')
  def order(count: 10, notes: 'Sem observacoes adicionais.')
    OpenStruct.new(account: account, contact: contact, order_items: (1..count).map { |i| item(i).tap { |row|
                     row.quantity = 10; row.unit_cents = 2000; row.one_time_cents = 20_000
                     row.recurring_cents = 0; row.monthly_cents = 0
                     row.snapshot = { 'billing_model' => 'one_time' }
                   } },
                   implementation_items: [], snapshot: { 'financial_version' => 2 }, order_number: 'PED-AUDIT-001',
                   proposal: nil, owner: owner, business_unit: nil, deal: nil, products_cents: count * 20_000,
                   discount_cents: 0, shipping_cents: 0, total_cents: count * 20_000, monthly_cents: 0,
                   installments_count: 1, payment_method: 'pix', payment_condition: 'cash', notes: notes)
  end
  def proposal(description: 'Descricao breve.', notes: 'Observacoes breves.')
    deal = OpenStruct.new(title: 'Negocio', owner: owner, account: account)
    OpenStruct.new(account: account, deal: deal, customer_contact: contact, owner: owner, title: 'Proposta de teste',
                   solution_description: description, proposal_number: 'PROP-AUDIT-001', valid_until: Date.new(2026, 10, 10),
                   proposal_items: (1..10).map { |i| item(i) }, total_cents: 20000, shipping_mode: 'separate', shipping_cents: 1000,
                   contract_total_cents: 261000, payment_condition: 'down_payment_installments', down_payment_cents: 3000,
                   installments_count: 3, payment_method: 'pix', payable_base_cents: 21000, installment_plan_cents: [6000,6000,6000],
                   :'shipping_in_installments?' => true, :'has_monthly_fee?' => true, monthly_cents: 20000, term_months: 12,
                   commercial_notes: notes)
  end
  def contract(count: 17, content: nil)
    source = order(count: count)
    source.order_items = (1..count).map { |i| item(i) }
    source.products_cents = source.total_cents = count * 2000
    source.monthly_cents = count * 2000
    OpenStruct.new(account: account, sales_order: source, deal: nil, contact: contact, contract_items: source.order_items,
                   contract_number: 'CON-AUDIT-001', one_time_cents: count * 2000, monthly_cents: count * 2000,
                   starts_on: Date.new(2026, 9, 22), ends_on: Date.new(2027, 9, 22), renewal_type: 'manual',
                   adjustment_index: 'IPCA', owner: owner, content_override: content, contract_template: nil, notes: '')
  end
  def long_text = (1..120).map { |i| "Linha #{i}: condicao comercial a preservar integralmente." }.join("\n")
  def assert_coordinates_inside(pdf)
    positions = pdf.scan(/BT \/F[12] [\d.]+ Tf ([\d.-]+) ([\d.-]+) Td/).map { |x,y| [x.to_f,y.to_f] }
    assert positions.any?
    assert positions.all? { |x,y| x >= 0 && x < 595.28 && y >= 30 && y < 841.89 }, 'PDF has off-page text coordinates'
  end
end
class CommercialPdfTest < Minitest::Test
  include CommercialPdfFixtures
  def test_direct_order_preserves_four_page_layout_for_ten_items
    pdf = AuditOrderPdf.new(order).call
    assert pdf.start_with?('%PDF-1.4')
    assert_equal 4, pdf.scan(%r{/Type /Page\b}).size
    assert_includes pdf, 'R$ 2.000,00'
    assert_coordinates_inside(pdf)
  end
  def test_order_long_notes_are_paginated_without_loss
    pdf = AuditOrderPdf.new(order(notes: long_text)).call
    assert_includes pdf, 'Linha 120:'
    assert_coordinates_inside(pdf)
  end
  def test_other_account_proposal_has_no_gopure_identity
    pdf = AuditProposalPdf.new(proposal).call
    refute pdf.match?(/gopure/i), 'Another tenant received a fixed GoPure identity'
    assert_includes pdf, 'Empresa Independente'
  end
  def test_proposal_expanded_conditions_stay_inside_pages
    assert_coordinates_inside(AuditProposalPdf.new(proposal).call)
  end
  def test_proposal_long_description_and_notes_are_not_lost
    pdf = AuditProposalPdf.new(proposal(description: long_text, notes: long_text)).call
    assert_includes pdf, 'Linha 120:'
    assert_coordinates_inside(pdf)
  end
  def test_contract_keeps_all_items_not_only_first_seven
    pdf = AuditContractPdf.new(contract).call
    assert_includes pdf, 'Item 017'
    assert_coordinates_inside(pdf)
  end
  def test_contract_uses_actual_company_not_fixed_gopure
    pdf = AuditContractPdf.new(contract(count: 1)).call
    refute pdf.match?(/gopure/i), 'Another tenant received a fixed GoPure identity'
    assert_includes pdf, 'Empresa Independente'
  end
  def test_contract_long_clauses_stay_inside_pages
    pdf = AuditContractPdf.new(contract(content: long_text)).call
    assert_includes pdf, 'Linha 120:'
    assert_coordinates_inside(pdf)
  end
  def test_pdf_literal_escapes_backslash_and_parentheses
    escaped = JrcCrm::ProposalPdfService::Page.new.send(:escape, 'C:\\clientes (teste)')
    assert_equal "C:\\\\clientes \\(teste\\)", escaped
  end
end

if ENV['CRM_PDF_EVIDENCE_DIR']
  require 'fileutils'
  out = ENV.fetch('CRM_PDF_EVIDENCE_DIR')
  FileUtils.mkdir_p(out)
  fixtures = Object.new.extend(CommercialPdfFixtures)
  { 'order-direct' => AuditOrderPdf.new(fixtures.order),
    'order-long-notes' => AuditOrderPdf.new(fixtures.order(notes: fixtures.long_text)),
    'proposal-mixed' => AuditProposalPdf.new(fixtures.proposal),
    'proposal-long' => AuditProposalPdf.new(fixtures.proposal(description: fixtures.long_text, notes: fixtures.long_text)),
    'contract-17-items' => AuditContractPdf.new(fixtures.contract),
    'contract-long' => AuditContractPdf.new(fixtures.contract(content: fixtures.long_text)) }.each do |name, service|
    File.binwrite(File.join(out, "#{name}.pdf"), service.call)
  end
end
