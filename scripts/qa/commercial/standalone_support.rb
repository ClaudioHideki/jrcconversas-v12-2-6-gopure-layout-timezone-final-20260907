# Test-only compatibility helpers for isolated, dependency-free checks.
# This file is NEVER loaded by the application or by the Rails/RSpec suite.
# It does not emulate ActiveRecord, HTTP requests, persistence or authorization.
raise 'Run standalone only, without Rails/ActiveRecord loaded' if defined?(ActiveRecord::Base)
require 'bigdecimal'
require 'bigdecimal/util'
require 'date'
require 'json'
require 'minitest/autorun'

class Object
  def blank? = respond_to?(:empty?) ? !!empty? : !self
  def present? = !blank?
  def presence = (present? ? self : nil)
end
class String
  def blank? = strip.empty?
end
class AuditIndifferentHash < Hash
  def initialize(values = {})
    super()
    values.each { |key, value| self[key] = value }
  end
  def [](key) = super(key.to_s)
  def key?(key) = super(key.to_s)
  def []=(key, value)
    super(key.to_s, value.is_a?(Hash) ? AuditIndifferentHash.new(value) : value)
  end
  def merge(other) = self.class.new(super(other.transform_keys(&:to_s)))
  def with_indifferent_access = self
end
class Hash
  def with_indifferent_access = AuditIndifferentHash.new(self)
  def stringify_keys = transform_keys(&:to_s)
end
class Date
  def self.current = new(2026, 9, 22)
end
