# Provider-boundary regression; no Rails boot, database, credentials or real sends.
require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/inclusion'
require 'active_support/core_ext/numeric/bytes'
require 'base64'
require 'json'
require 'uri'
require 'tempfile'
require 'vips'

module JrcCampaigns; end

module SafeFetch
  class Error < StandardError; end
  class HttpError < Error; end
  Result = Data.define(:tempfile, :filename, :content_type)

  def self.fetch(*)
    raise 'Network disabled in this regression'
  end
end

require_relative '../../../app/services/jrc_campaigns/evolution_client'

class EvolutionMediaTest < Minitest::Test
  Connector = Data.define(:base_url, :instance, :api_key)

  def test_png_caption_is_sent_as_jpeg_with_matching_filename_and_mime
    png = Vips::Image.black(2, 2).pngsave_buffer
    requests = []
    fetch = lambda do |url, **options, &block|
      Tempfile.create('gopure-campaign-media') do |file|
        file.binmode
        if url == 'https://media.example.test/image'
          file.write(png)
          type = 'image/png'
        else
          requests << JSON.parse(options.fetch(:body))
          file.write({ key: { id: 'synthetic-image', fromMe: true, remoteJid: '5511999999000@s.whatsapp.net' } }.to_json)
          type = 'application/json'
        end
        file.rewind
        block.call(SafeFetch::Result.new(tempfile: file, filename: 'extensionless', content_type: type))
      end
    end
    connector = Connector.new(base_url: 'https://evolution.example.test', instance: 'isolated', api_key: 'fixture-only')
    SafeFetch.stub(:fetch, fetch) do
      result = JrcCampaigns::EvolutionClient.new(connector).send_message(
        phone_number: '+5511999999000', kind: 'image', body: 'Imagem com legenda', media_url: 'https://media.example.test/image', file_name: 'convite.png'
      )
      assert_equal 'synthetic-image', result
    end
    assert_equal 1, requests.size
    payload = requests.fetch(0)
    assert_equal 'Imagem com legenda', payload.fetch('caption')
    assert_equal 'image.jpg', payload.fetch('fileName')
    assert_equal 'image/jpeg', payload.fetch('mimetype')
    jpeg = Base64.strict_decode64(payload.fetch('media'))
    assert jpeg.start_with?("\xFF\xD8".b)
    assert_equal [2, 2], [Vips::Image.new_from_buffer(jpeg, '').width, Vips::Image.new_from_buffer(jpeg, '').height]
  end
end
