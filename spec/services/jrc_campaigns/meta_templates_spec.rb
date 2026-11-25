require 'rails_helper'

RSpec.describe JrcCampaigns::TemplateConfiguration do
  let(:account) { create(:account) }
  let(:channel) { build_stubbed(:channel_whatsapp, account: account) }
  let(:inbox) { build_stubbed(:inbox, account: account, channel: channel) }
  let(:components) { [{ 'type' => 'BODY', 'text' => 'Olá {{1}}' }] }
  let(:template) { { 'name' => 'approved', 'language' => 'pt_BR', 'status' => 'APPROVED', 'components' => components } }
  let(:params) { { 'processed_params' => { 'body' => { '1' => 'Ana' } } } }
  let(:step) { { 'kind' => 'template', 'template_name' => 'approved', 'template_language' => 'pt_BR', 'template_params' => params } }
  let(:configuration) { described_class.new(inbox: inbox, step: step) }

  before { allow(channel).to receive(:message_templates).and_return([template]) }

  it 'accepts approved text and preserves a positional body parameter' do
    expect(described_class.new(inbox: inbox, step: step).validate!).to eq(template)
  end

  it 'rejects missing body variables instead of sending an incomplete message' do
    step['template_params'] = {}
    expect { configuration.validate! }.to raise_error(ArgumentError, /variáveis/)
  end

  it 'rejects invalid JSON shapes without converting them to empty parameters' do
    step['template_params'] = []
    expect { configuration.validate! }.to raise_error(ArgumentError, /objeto JSON/)
  end

  it 'rejects a paused or disabled Meta template' do
    template['status'] = 'PAUSED'
    expect { configuration.validate! }.to raise_error(ArgumentError, /não aprovado/)
  end

  it 'rejects unsupported carousel components' do
    components << { 'type' => 'CAROUSEL' }
    expect { configuration.validate! }.to raise_error(ArgumentError, /não suportado/)
  end

  %w[IMAGE VIDEO DOCUMENT].each do |kind|
    it "requires a retained #{kind} header, never a temporary example URL" do
      components.unshift({ 'type' => 'HEADER', 'format' => kind, 'example' => { 'header_handle' => ['https://example.test/temporary'] } })
      expect { configuration.validate! }.to raise_error(ArgumentError, /cabeçalho obrigatório/)
    end
  end

  it 'requires variables for text headers' do
    components.unshift({ 'type' => 'HEADER', 'format' => 'TEXT', 'text' => '{{name}}' })
    expect { configuration.validate! }.to raise_error(ArgumentError, /header/)
    params['processed_params']['header'] = { 'name' => 'Nome' }
    expect(described_class.new(inbox: inbox, step: step).validate!).to eq(template)
  end

  it 'accepts fixed URL, phone and quick reply without sending extra parameters' do
    components << { 'type' => 'BUTTONS', 'buttons' => [{ 'type' => 'URL', 'url' => 'https://example.test' }, { 'type' => 'PHONE_NUMBER' }, { 'type' => 'QUICK_REPLY' }] }
    expect(described_class.new(inbox: inbox, step: step).validate!).to eq(template)
  end

  it 'requires a dynamic URL parameter at its actual button index' do
    components << { 'type' => 'BUTTONS', 'buttons' => [{ 'type' => 'PHONE_NUMBER' }, { 'type' => 'URL', 'url' => 'https://example.test/{{1}}' }] }
    expect { configuration.validate! }.to raise_error(ArgumentError, /botão 2/)
    params['processed_params']['buttons'] = [{}, { 'type' => 'url', 'parameter' => 'order-1' }]
    expect(described_class.new(inbox: inbox, step: step).validate!).to eq(template)
  end

  it 'validates inbox overrides rather than the default template alone' do
    step['inbox_overrides'] = { inbox.id.to_s => { 'template_name' => 'missing' } }
    expect { configuration.validate! }.to raise_error(ArgumentError, /não encontrado/)
  end
end
