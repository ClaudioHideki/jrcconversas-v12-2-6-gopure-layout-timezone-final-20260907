# Isolated test doubles, NOT the Rails runtime. Run only through services_test.rb.
# No DB, Redis, credentials or network is used. Production service files are loaded.
raise 'Run this suite standalone, without Rails loaded' if defined?(ActiveRecord::Base)
require 'minitest/autorun'
require 'ostruct'
require 'time'
require 'json'
require 'logger'
require 'stringio'

class Object
  def blank? = respond_to?(:empty?) ? !!empty? : !self
  def present? = !blank?
  def presence = present? ? self : nil
  def deep_dup = Marshal.load(Marshal.dump(self))
  def try(method, *args) = respond_to?(method) ? public_send(method, *args) : nil
end
class String
  def blank? = strip.empty?
  def first(n) = self[0, n]
end
class Hash
  def deep_stringify_keys
    transform_keys(&:to_s).transform_values do |value|
      if value.is_a?(Hash)
        value.deep_stringify_keys
      elsif value.is_a?(Array)
        value.map { |item| item.is_a?(Hash) ? item.deep_stringify_keys : item }
      else
        value
      end
    end
  end
end
class Time
  class << self
    attr_accessor :test_now
    def current = test_now || now
  end
end
class Module
  def prepend_mod_with(*) = nil # Enterprise extensions are not loaded here.
  def pattr_initialize(names)
    attrs = names.map { |name| name.to_s.delete_suffix('!').to_sym }
    attr_reader(*attrs)
    define_method(:initialize) do |**kwargs|
      attrs.each { |key| instance_variable_set("@#{key}", kwargs[key]) }
    end
  end
end
module ActiveModel
  module Type
    class Boolean
      def cast(value) = ![false, nil, '', 0, '0', 'false', 'f', 'off', :false].include?(value)
    end
  end
end
module Rails
  def self.logger = @logger ||= Logger.new(StringIO.new)
end
module Whatsapp
  module Providers; end
  module IncomingMessageServiceHelpers
    def referral_attributes(*) = nil
  end
  module IncomingMessageIdentifierHelper; end
end

class FakeRelation
  attr_reader :rows, :queries
  def initialize(rows, queries = [])
    @rows, @queries = rows, queries
  end
  def where(criteria = nil)
    return self unless criteria
    @queries << criteria
    rows = if criteria.is_a?(Hash)
             # The isolated doubles do not model SQL joins. The integration
             # suite verifies the conversation/contact-inbox predicate.
             criteria = criteria.reject { |key, _| key == :conversations }
             @rows.select { |row| matches?(row, criteria) }
           elsif criteria.include?('whatsapp_window_timestamp_untrusted')
             @rows.reject { |row| row.content_attributes['whatsapp_window_timestamp_untrusted'].to_s == 'true' }
           elsif criteria.include?('template_params')
             @rows.select { |row| row.additional_attributes['template_params'] }
           else
             raise "Unhandled query in isolated test: #{criteria}"
           end
    self.class.new(rows, @queries)
  end
  def joins(*) = self
  def not(criteria)
    self.class.new(@rows.reject { |row| matches?(row, criteria) }, @queries)
  end
  def maximum(key) = @rows.map { |row| row.public_send(key) }.compact.max
  def pluck(key) = @rows.map { |row| row.public_send(key) }
  private
  def matches?(row, criteria)
    criteria.all? do |key, values|
      Array(values).any? { |value| row.public_send(key).to_s == value.to_s }
    end
  end
end
class Message
  class << self
    attr_accessor :rows, :queries
    def joins(*) = FakeRelation.new(rows || [], queries || [])
    def where(criteria) = FakeRelation.new(rows || [], queries || []).where(criteria)
  end
end
class FakeChannel
  attr_accessor :provider, :provider_config, :message_templates,
                :message_templates_last_updated, :updated_at, :inbox, :loader
  attr_reader :account_id, :id
  def initialize
    @id, @account_id, @provider = 2, 1, 'whatsapp_cloud'
    @provider_config = { 'api_key' => 'fake-test-only', 'business_account_id' => '100', 'phone_number_id' => '200' }
    @message_templates = []
  end
  def with_lock = yield
  def update_columns(columns)
    columns.each { |key, value| public_send("#{key}=", value) }
  end
  def provider_service = self
  def load_templates! = loader.call
end
class FakeInbox < OpenStruct
  def update_account_cache = self.cache_updates = (cache_updates || 0) + 1
end
module HTTParty
  class << self
    attr_accessor :responses, :requests
    def get(url, **kwargs)
      self.requests ||= []
      requests << [url, kwargs]
      response = responses.shift
      raise response if response.is_a?(Exception)
      raise 'No stubbed response: real network is forbidden' unless response
      response
    end
    def post(*) = raise('Network sends are forbidden in the isolated suite')
  end
end
class FakeResponse
  attr_reader :parsed_response
  def initialize(data, ok = true)
    @parsed_response, @ok = data, ok
  end
  def success? = @ok
  def [](key) = @parsed_response[key]
end
ROOT = File.expand_path('../../..', __dir__)
%w[conversation_window_service template_catalog_service template_parameter_converter_service
   outgoing_message_guard populate_template_parameters_service template_processor_service
   template_sync_service providers/base_service providers/whatsapp_cloud_service
   providers/whatsapp_360_dialog_service incoming_message_base_service].each do |file|
  require File.join(ROOT, 'app/services/whatsapp', "#{file}.rb")
end
