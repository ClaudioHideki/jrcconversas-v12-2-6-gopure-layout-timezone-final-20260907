class JrcCustomers::CompanyWriter
  class StaleRevision < StandardError; end

  def initialize(account:, actor:)
    @account = account
    @actor = actor
  end

  def save!(company:, attributes:, expected_revision: nil)
    raise ActiveRecord::RecordNotFound unless company.account_id == @account.id

    # Serializes hierarchy changes and makes the audit part of the same commit.
    @account.with_lock do
      company.reload if company.persisted?
      if expected_revision && company.updated_at&.iso8601(6) != expected_revision
        raise StaleRevision, 'This company changed since it was opened. Reload before saving.'
      end

      attributes = attributes.to_h.symbolize_keys
      primary_address = attributes.delete(:primary_address)
      created = company.new_record?
      if @actor && company.has_attribute?(:updated_by_id)
        attributes[:updated_by_id] = @actor.id
        attributes[:created_by_id] = @actor.id if created && company.created_by_id.blank?
      end

      audited_keys = attributes.keys.map(&:to_s)
      previous = company.attributes.slice(*audited_keys)
      company.assign_attributes(attributes)
      company.save!
      assign_customer_code!(company)
      save_primary_address!(company, primary_address) if primary_address

      JrcCustomers::Audit.record!(
        account: @account,
        actor: @actor,
        resource: company,
        event_type: created ? 'customer_company_created' : 'customer_company_updated',
        from_value: previous,
        to_value: company.attributes.slice(*(audited_keys + ['customer_code']).uniq)
      )
      company
    end
  end

  private

  def save_primary_address!(company, values)
    values = values.to_h.stringify_keys.slice('postal_code', 'street', 'number', 'complement', 'district', 'city', 'state', 'country')
    address = primary_business_address(company, values)
    return unless address

    previous = address.attributes
    address.assign_attributes(values)
    return unless address.changed?

    address.save!
    company.update!(updated_at: Time.current)
    JrcCustomers::Audit.record!(account: @account, actor: @actor, resource: company,
                                event_type: 'customer_address_changed', metadata: { action: 'saved' },
                                from_value: previous, to_value: address.attributes)
  end

  def primary_business_address(company, values)
    address = company.addresses.where(account_id: @account.id, address_type: 'business').order(:id).first
    return address if address
    return if values.except('country').values.all?(&:blank?)

    raise ActionController::BadRequest, 'Maximum of 100 addresses per company' if company.addresses.count >= 100

    company.addresses.new(account_id: @account.id, address_type: 'business')
  end

  def assign_customer_code!(company)
    return unless company.has_attribute?(:customer_code) && company.customer_code.blank?

    company.update_column(:customer_code, format('EMP-%06d', company.id))
  end
end
