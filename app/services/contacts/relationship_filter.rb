# Relationship tabs use the existing company association, labels and CRM ownership.
# Duplicate candidates are reported only; this query never merges or changes contacts.
class Contacts::RelationshipFilter
  def initialize(scope, account, params)
    @scope, @account, @params = scope, account, params
  end

  def call
    scope = case @params[:relationship]
            when 'people' then @scope.where(company_id: nil).where("COALESCE(additional_attributes->>'company_name', '') = ''")
            when 'companies' then @scope.where("company_id IS NOT NULL OR COALESCE(additional_attributes->>'company_name', '') <> ''")
            when 'groups' then @scope.where(id: @scope.joins(:taggings).select(:id))
            when 'unassigned' then @scope.where.not(id: assigned_contact_ids)
            when 'duplicates' then duplicates
            else @scope
            end
    scope = scope.where(id: assigned_contact_ids(@params[:owner_id])) if @params[:owner_id].present?
    scope = scope.where(contact_type: Contact.contact_types.fetch(@params[:status])) if Contact.contact_types.key?(@params[:status])
    if @params[:channel].present?
      scope = scope.where(id: @account.contacts.joins(:inboxes).where(inboxes: { channel_type: @params[:channel] }).select(:id))
    end
    scope
  end

  private

  def assigned_contact_ids(owner_id = nil)
    leads = @account.jrc_crm_leads.where.not(contact_id: nil).where.not(owner_id: nil)
    deals = @account.jrc_crm_deals.where.not(contact_id: nil).where.not(owner_id: nil)
    leads = leads.where(owner_id: owner_id) if owner_id.present?
    deals = deals.where(owner_id: owner_id) if owner_id.present?
    # Both subqueries stay scoped to the account, including the OR branch.
    @account.contacts.where(id: leads.select(:contact_id)).or(@account.contacts.where(id: deals.select(:contact_id))).select(:id)
  end

  def duplicates
    @scope.where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM contacts candidate
        WHERE candidate.account_id = contacts.account_id AND candidate.id <> contacts.id
        AND (
          (NULLIF(LOWER(TRIM(contacts.email)), '') IS NOT NULL AND LOWER(TRIM(candidate.email)) = LOWER(TRIM(contacts.email)))
          OR (NULLIF(REGEXP_REPLACE(contacts.phone_number, '[^0-9]', '', 'g'), '') IS NOT NULL
              AND REGEXP_REPLACE(candidate.phone_number, '[^0-9]', '', 'g') = REGEXP_REPLACE(contacts.phone_number, '[^0-9]', '', 'g'))
          OR (NULLIF(contacts.identifier, '') IS NOT NULL AND candidate.identifier = contacts.identifier)
        )
      )
    SQL
  end
end
