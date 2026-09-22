# Isolated validation only: no Rails, HTTP, database or policy emulation.
require_relative 'standalone_support'
require_relative '../../../app/services/jrc_crm/stage_reorder_input'
require_relative '../../../app/services/jrc_crm/commercial_document_brand'
require 'ostruct'

class CommercialInputTest < Minitest::Test
  def test_stage_reorder_accepts_integer_and_json_string_keys
    assert_equal [[42, 43], [2, 1]], JrcCrm::StageReorderInput.call([{id: 42, position: 2}, {'id' => '43', 'position' => '1'}])
  end
  def test_stage_reorder_rejects_truncated_or_invalid_values
    [nil, 0, -1, 1.5, '1oops', '1.5', true, {}, ' 2', ''].each do |value|
      assert_raises(ArgumentError) { JrcCrm::StageReorderInput.call([{id: value, position: 1}]) }
      assert_raises(ArgumentError) { JrcCrm::StageReorderInput.call([{id: 42, position: value}]) }
    end
  end
  def test_stage_reorder_rejects_duplicate_ids_or_positions
    assert_raises(ArgumentError) { JrcCrm::StageReorderInput.call([{id: 42, position: 1}, {id: 42, position: 2}]) }
    assert_raises(ArgumentError) { JrcCrm::StageReorderInput.call([{id: 42, position: 1}, {id: 43, position: 1}]) }
  end
  def test_stage_reorder_rejects_malformed_collections
    [nil, [], {}, {id: 42, position: 1}, [nil], ['invalid']].each do |value|
      assert_raises(ArgumentError) { JrcCrm::StageReorderInput.call(value) }
    end
  end
  def test_contact_page_never_produces_a_negative_offset
    # Execute the exact current production method, independently of controller dependencies.
    source = File.read(File.expand_path('../../../app/controllers/api/v1/accounts/contacts_controller.rb', __dir__))
    method = source[/^  def set_current_page\n.*?^  end/m]
    raise 'Production method not found' unless method
    receiver = Class.new { attr_accessor :params }.new
    receiver.singleton_class.class_eval(method, 'contacts_controller#set_current_page')
    [nil, 0, -4, 'invalid', 1].each do |page|
      receiver.params = {page: page}; receiver.set_current_page
      assert_equal 1, receiver.instance_variable_get(:@current_page)
    end
    receiver.params = {page: '31'}; receiver.set_current_page
    assert_equal 31, receiver.instance_variable_get(:@current_page)
  end
  def brand(account)
    Object.new.extend(JrcCrm::CommercialDocumentBrand).send(:document_gopure?, OpenStruct.new(account))
  end
  def test_gopure_brand_name_fallback_and_explicit_opt_out
    assert brand(name: ' Go Pure ', custom_attributes: {})
    refute brand(name: 'GoPure', custom_attributes: {'crm_theme' => 'default'})
    refute brand(name: 'Outra Empresa', custom_attributes: {})
  end
  def test_gopure_brand_explicit_opt_in_does_not_require_company_rename
    assert brand(name: 'Outra Empresa', custom_attributes: {'crm_theme' => 'gopure'})
  end
end
