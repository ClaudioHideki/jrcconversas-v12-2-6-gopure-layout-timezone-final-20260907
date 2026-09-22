# Run: ruby scripts/qa/whatsapp24h/services_test.rb
require_relative 'runtime'
class WhatsappServicesTest < Minitest::Test
  def setup
    Time.test_now = Time.utc(2026, 9, 21, 19, 0, 0)
    Message.rows, Message.queries = [], []
    HTTParty.responses, HTTParty.requests = [], []
    @channel = FakeChannel.new
    @account = OpenStruct.new(id: 1, name: 'Empresa de teste', teams: FakeRelation.new([OpenStruct.new(id: 5, name: 'Suporte')]))
    @inbox = FakeInbox.new(id: 7, account_id: 1, account: @account, channel_type: 'Channel::Whatsapp', channel: @channel)
    @channel.inbox = @inbox
    @contact = OpenStruct.new(id: 10, name: "Ana D'Avila", phone_number: '+5511000000000', email: 'test@example.invalid')
    @user = OpenStruct.new(id: 3, name: 'Agente teste')
    @conversation = OpenStruct.new(id: 80, display_id: 22, inbox_id: 7, inbox: @inbox,
      account_id: 1, contact_id: 10, contact: @contact, account: @account, team_id: 5,
      team: OpenStruct.new(name: 'Suporte'), messages: FakeRelation.new([]))
    @template = { 'id' => '900', 'name' => 'retomar', 'language' => 'pt_BR', 'status' => 'APPROVED',
      'category' => 'UTILITY', 'components' => [{ 'type' => 'BODY', 'text' => 'Ola {{1}}, protocolo {{2}}.' }] }
    @channel.message_templates = [@template]
  end
  def teardown = Time.test_now = nil
  def record(**overrides)
    defaults = { account_id: 1, inbox_id: 7, sender_type: 'Contact', sender_id: 10,
      message_type: 'incoming', private: false, content_type: 'text', created_at: Time.current - 10,
      content_attributes: {}, additional_attributes: {}, status: 'sent', source_id: 'wamid.test' }
    OpenStruct.new(defaults.merge(overrides))
  end
  def window = Whatsapp::ConversationWindowService.new(@conversation)
  def catalog = Whatsapp::TemplateCatalogService.new(inbox: @inbox, conversation: @conversation, user: @user)
  def guard = Whatsapp::OutgoingMessageGuard.new(@conversation, user: @user)
  def params(values = { 'body' => { '1' => @contact.name, '2' => '#22' } })
    { 'name' => 'retomar', 'language' => 'pt_BR', 'processed_params' => values }
  end
  def test_window_without_incoming_requires_template
    refute window.can_send_free_message?
    assert_equal 'TEMPLATE_REQUIRED', window.payload[:window_status]
  end
  def test_window_open_until_but_not_at_24_hours
    Message.rows = [record(created_at: Time.current - 86_399)]
    assert window.can_send_free_message?
    assert_equal 1, window.payload[:remaining_seconds]
    Message.rows = [record(created_at: Time.current - 86_400)]
    refute window.can_send_free_message?
    assert_equal 'CLOSED', window.payload[:window_status]
  end
  def test_window_is_scoped_to_account_inbox_contact_and_sender
    Message.rows = [record(account_id: 2), record(inbox_id: 8), record(sender_id: 11), record(sender_type: 'User')]
    refute window.can_send_free_message?
    assert Message.queries.any? { |q| q.is_a?(Hash) && q[:account_id] == 1 && q[:inbox_id] == 7 && q[:sender_id] == 10 }
  end
  def test_agent_notes_templates_calls_and_invalid_timestamps_do_not_open_window
    Message.rows = [record(message_type: 'outgoing'), record(message_type: 'template'), record(private: true),
      record(content_type: 'voice_call'), record(content_attributes: { 'whatsapp_window_timestamp_untrusted' => true })]
    refute window.can_send_free_message?
  end
  def test_latest_customer_message_is_used_despite_delivery_order
    Message.rows = [record(created_at: Time.current - 40), record(created_at: Time.current - 200_000)]
    assert_equal Time.current - 40, window.last_customer_message_at
    assert window.can_send_free_message?
  end
  def test_sent_template_does_not_open_window
    @conversation.messages = FakeRelation.new([record(message_type: 'outgoing', sender_type: 'User', additional_attributes: { 'template_params' => params })])
    refute window.can_send_free_message?
    assert window.payload[:awaiting_customer_reply]
  end
  def test_customer_reply_reopens_window_after_template
    @conversation.messages = FakeRelation.new([record(created_at: Time.current - 30, message_type: 'outgoing', additional_attributes: { 'template_params' => params })])
    Message.rows = [record]
    assert window.can_send_free_message?
    refute window.payload[:awaiting_customer_reply]
  end
  def test_future_inbound_timestamp_fails_closed
    Message.rows = [record(created_at: Time.current + 30)]
    refute window.can_send_free_message?
    assert_equal 'UNKNOWN', window.payload[:window_status]
  end
  def test_non_native_channels_are_not_changed
    %w[Channel::Api Channel::Email Channel::Instagram Channel::TwilioSms].each do |type|
      @inbox.channel_type = type
      assert_nil window.payload
      assert_nil guard.call
    end
  end
  def test_free_message_blocked_outside_window
    error = assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call }
    assert_equal 'WHATSAPP_WINDOW_CLOSED', error.code
  end
  def test_free_message_allowed_only_when_window_open
    Message.rows = [record]
    assert_nil guard.call
  end
  def test_private_notes_bypass_window_but_string_false_does_not
    assert_nil guard.call(private_note: true)
    assert_nil guard.call(private_note: 'true')
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(private_note: 'false') }
  end
  def test_approved_template_is_canonical_and_preserves_quotes
    result = guard.call(template_params: params.merge('category' => 'MARKETING', 'namespace' => 'spoof'))
    assert_equal "Ola Ana D'Avila, protocolo #22.", result[:content]
    assert_equal 'UTILITY', result[:template_params]['category']
    refute result[:template_params].key?('namespace')
    assert_equal 64, result[:audit]['template_version'].size
    assert_equal 1, result[:audit]['account_id']
    assert_equal 3, result[:audit]['agent_id']
  end
  def test_rejected_pending_paused_disabled_and_other_account_templates_blocked
    %w[PENDING REJECTED PAUSED DISABLED UNKNOWN].each do |status|
      @template['status'] = status
      assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params) }
    end
    @channel.message_templates = []
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params) }
  end
  def test_template_language_and_id_are_checked
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params.merge('language' => 'en_US')) }
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params.merge('id' => '901')) }
  end
  def test_required_body_parameters_and_length
    [{ '1' => '' }, { '1' => 'Ana', '2' => '' }, { '1' => "Ana\nTeste", '2' => 'x' },
     { '1' => 'A' * 1001, '2' => 'x' }].each do |values|
      assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params('body' => values)) }
    end
  end
  def test_positional_parameters_are_sorted_not_request_order
    result = guard.call(template_params: params('body' => { '2' => '#22', '1' => 'Ana' }))
    assert_equal %w[1 2], result[:template_params]['processed_params']['body'].keys
  end
  def test_legacy_array_parameters_still_work
    assert_equal 'Ola Ana, protocolo #22.', guard.call(template_params: params(['Ana', '#22']))[:content]
  end
  def test_static_template_requires_no_parameters
    @template['components'][0]['text'] = 'Ola!'
    assert_equal 'Ola!', guard.call(template_params: params(nil))[:content]
  end
  def test_header_and_dynamic_buttons_are_validated
    @template['components'] << { 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Pedido {{1}}' }
    @template['components'] << { 'type' => 'BUTTONS', 'buttons' => [
      { 'type' => 'URL', 'text' => 'Site', 'url' => 'https://example.invalid' },
      { 'type' => 'URL', 'text' => 'Pedido', 'url' => 'https://example.invalid/{{1}}' },
      { 'type' => 'COPY_CODE', 'text' => 'Copiar' } ] }
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params) }
    data = params
    data['processed_params'].merge!('header' => { '1' => '22' }, 'buttons' => [
      { 'type' => 'url' }, { 'type' => 'url', 'parameter' => '22' }, { 'type' => 'copy_code', 'parameter' => 'TESTE' }])
    result = guard.call(template_params: data)
    refute result[:template_params]['processed_params']['buttons'][0].key?('parameter')
    data['processed_params']['buttons'][2]['parameter'] = 'X' * 16
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: data) }
  end
  def test_media_header_rejects_missing_invalid_and_credential_urls
    @template['components'] << { 'type' => 'HEADER', 'format' => 'IMAGE' }
    [nil, 'file:///etc/passwd', 'https://user:password@example.invalid/a.png', 'javascript:alert(1)'].each do |url|
      data = params
      data['processed_params']['header'] = { 'media_url' => url }
      assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: data) }
    end
    data = params
    data['processed_params']['header'] = { 'media_type' => 'video', 'media_url' => 'https://example.invalid/a.png' }
    result = guard.call(template_params: data)
    assert_equal 'image', result[:template_params]['processed_params']['header']['media_type']
  end
  def test_named_header_and_body_reach_provider_parameters
    @template['parameter_format'] = 'NAMED'
    @template['components'] = [{ 'type' => 'BODY', 'text' => 'Ola {{nome}}' }, { 'type' => 'HEADER', 'format' => 'TEXT', 'text' => 'Pedido {{numero}}' }]
    data = params('body' => { 'nome' => "D'Avila" }, 'header' => { 'numero' => '22' })
    result = guard.call(template_params: data)
    processed = Whatsapp::TemplateProcessorService.new(channel: @channel, template_params: result[:template_params]).call[3]
    assert_equal 'numero', processed[0][:parameters][0][:parameter_name]
    assert_equal "D'Avila", processed[1][:parameters][0][:text]
  end
  def test_processor_never_returns_unavailable_template_name
    @channel.message_templates = []
    assert_equal [nil, nil, nil, nil], Whatsapp::TemplateProcessorService.new(channel: @channel, template_params: params).call
  end
  def test_catalog_hides_unsupported_components_but_admin_can_inspect
    @template['components'] << { 'type' => 'CAROUSEL' }
    assert_empty catalog.templates
    assert_equal false, catalog.templates(management: true)[0]['jrc']['supported']
  end
  def test_malformed_component_fails_closed
    @template['components'] << 'malformed'
    assert_empty catalog.templates
    assert_equal false, catalog.templates(management: true)[0]['jrc']['supported']
  end
  def test_team_restriction_and_internal_disable_enforced_on_send
    @channel.provider_config['jrc_template_settings'] = { 'rules' => { 'retomar|pt_BR' => { 'team_ids' => [6] } } }
    assert_empty catalog.templates
    assert_raises(Whatsapp::OutgoingMessageGuard::Error) { guard.call(template_params: params) }
    @channel.provider_config['jrc_template_settings']['rules']['retomar|pt_BR'] = { 'enabled' => false }
    assert_empty catalog.templates
  end
  def test_team_rules_favorites_and_numeric_autofill_persist_without_changing_credentials
    assert_empty catalog.templates[0]['jrc']['defaults']
    result = catalog.update_rule!('retomar|pt_BR', { 'enabled' => true, 'favorite' => true, 'team_ids' => [5], 'bindings' => { 'body.1' => 'contact.name', 'body.2' => 'conversation.display_id' } })
    assert result['jrc']['favorite']
    assert_equal "Ana D'Avila", result['jrc']['defaults']['body.1']
    assert_equal '#22', result['jrc']['defaults']['body.2']
    assert_equal 'fake-test-only', @channel.provider_config['api_key']
    assert_equal 1, @inbox.cache_updates
    assert guard.call(template_params: params)
  end
  def test_no_team_cannot_access_restricted_template
    @channel.provider_config['jrc_template_settings'] = { 'rules' => { 'retomar|pt_BR' => { 'team_ids' => [5] } } }
    @conversation.team_id = nil
    assert_empty catalog.templates
  end
  def test_cannot_link_other_account_team_or_sensitive_variable_source
    assert_raises(ArgumentError) { catalog.update_rule!('retomar|pt_BR', { 'team_ids' => [99] }) }
    assert_raises(ArgumentError) { catalog.update_rule!('retomar|pt_BR', { 'bindings' => { 'body.1' => 'channel.api_key' } }) }
  end
  def test_named_variables_can_be_suggested_without_guessing_numeric_positions
    @template['components'][0]['text'] = 'Ola {{nome}}, {{protocolo}} / {{1}}'
    defaults = catalog.templates[0]['jrc']['defaults']
    assert_equal "Ana D'Avila", defaults['body.nome']
    assert_equal '#22', defaults['body.protocolo']
    refute defaults.key?('body.1')
  end
  def test_sync_success_and_empty_catalog_replace_stale_templates
    @channel.loader = -> { [] }
    assert_equal [], Whatsapp::TemplateSyncService.new(@channel).call
    assert_empty @channel.message_templates
    assert_equal Time.current, @channel.message_templates_last_updated
    assert_nil @channel.provider_config['jrc_template_settings']['last_error']
    assert_equal 'fake-test-only', @channel.provider_config['api_key']
  end
  def test_failed_sync_preserves_cache_and_success_timestamp
    original = @channel.message_templates.deep_dup
    old = @channel.message_templates_last_updated = Time.current - 1000
    @channel.loader = -> { raise 'provider offline' }
    assert_raises(Whatsapp::TemplateSyncService::Error) { Whatsapp::TemplateSyncService.new(@channel).call }
    assert_equal original, @channel.message_templates
    assert_equal old, @channel.message_templates_last_updated
    assert @channel.provider_config['jrc_template_settings']['last_error']
  end
  def test_invalid_sync_response_preserves_cache
    @channel.loader = -> { [{ 'status' => 'APPROVED' }] }
    assert_raises(Whatsapp::TemplateSyncService::Error) { Whatsapp::TemplateSyncService.new(@channel).call }
    assert_equal [@template], @channel.message_templates
  end
  def test_cloud_sync_all_pages_uses_fixed_host_and_header_auth
    HTTParty.responses = [FakeResponse.new({ 'data' => [@template], 'paging' => { 'next' => 'https://evil.invalid/token', 'cursors' => { 'after' => 'cursor2' } } }), FakeResponse.new({ 'data' => [] })]
    service = Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: @channel)
    assert_equal [@template], service.load_templates!
    assert_equal 2, HTTParty.requests.size
    refute HTTParty.requests.any? { |url, _| url.include?('evil.invalid') || url.include?('fake-test-only') }
    assert_equal 'cursor2', HTTParty.requests[1][1][:query][:after]
    assert_equal 'Bearer fake-test-only', HTTParty.requests[0][1][:headers]['Authorization']
  end
  def test_cloud_sync_cyclic_cursor_or_later_failed_page_rejected
    page = { 'data' => [@template], 'paging' => { 'next' => 'next', 'cursors' => { 'after' => 'same' } } }
    HTTParty.responses = [FakeResponse.new(page), FakeResponse.new(page)]
    service = Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: @channel)
    assert_raises(Whatsapp::TemplateSyncService::Error) { service.load_templates! }
    HTTParty.responses = [FakeResponse.new(page), FakeResponse.new({ 'error' => 'fail' }, false)]
    assert_raises(Whatsapp::TemplateSyncService::Error) { service.load_templates! }
  end
  def test_360_provider_uses_same_atomic_sync_contract
    @channel.provider = 'default'
    HTTParty.responses = [FakeResponse.new({ 'waba_templates' => [@template] })]
    service = Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: @channel)
    assert_equal [@template], service.load_templates!
    assert_equal 'fake-test-only', HTTParty.requests[0][1][:headers]['D360-API-KEY']
  end
  def test_incoming_uses_provider_timestamp_not_webhook_processing_time
    service = Whatsapp::IncomingMessageBaseService.new(inbox: @inbox, params: {})
    old = Time.current - 100_000
    assert_equal old, service.send(:provider_message_time, { timestamp: old.to_i.to_s })
    [nil, '', 'not-a-time', (Time.current + 61).to_i.to_s].each do |value|
      assert_nil service.send(:provider_message_time, { timestamp: value })
    end
    assert_equal true, service.send(:message_content_attributes, {})[:whatsapp_window_timestamp_untrusted]
  end
  def test_static_buttons_do_not_send_empty_provider_parameters
    @template['components'] << { 'type' => 'BUTTONS', 'buttons' => [{ 'type' => 'URL', 'text' => 'Site', 'url' => 'https://example.invalid' }] }
    result = guard.call(template_params: params)
    components = Whatsapp::TemplateProcessorService.new(channel: @channel, template_params: result[:template_params]).call[3]
    refute components.any? { |component| component[:type] == 'button' }
  end
  def test_queued_template_is_not_reported_as_provider_accepted
    @conversation.messages = FakeRelation.new([record(message_type: 'outgoing', source_id: nil, additional_attributes: { 'template_params' => params })])
    refute window.payload[:awaiting_customer_reply]
    refute window.can_send_free_message?
  end
  def test_processor_blocks_restricted_or_disabled_templates_without_context
    @channel.provider_config['jrc_template_settings'] = { 'rules' => { 'retomar|pt_BR' => { 'team_ids' => [5] } } }
    assert_nil Whatsapp::TemplateProcessorService.new(channel: @channel, template_params: params).call[0]
    @channel.provider_config['jrc_template_settings']['rules']['retomar|pt_BR'] = { 'enabled' => false }
    assert_nil Whatsapp::TemplateProcessorService.new(channel: @channel, template_params: params).call[0]
  end
  def test_delivery_status_cannot_regress_from_read_or_be_overwritten_by_late_failure
    service = Whatsapp::IncomingMessageBaseService.new(inbox: @inbox, params: {})
    msg = record(status: 'read')
    msg.define_singleton_method(:read?) { status == 'read' }
    msg.define_singleton_method(:delivered?) { status == 'delivered' }
    msg.define_singleton_method(:save!) { self.saved = true }
    service.send(:update_message_with_status, msg, { status: 'sent' })
    service.send(:update_message_with_status, msg, { status: 'failed' })
    assert_equal 'read', msg.status
    refute msg.saved
  end

end
