# Read-only records behind the lead/proposal counters. Commercial values and
# deal stages remain independent: a historical send must never reopen a deal.
class JrcCrm::FunnelRecordsService
  def initialize(account:, actor:, filters: {}, search: nil)
    @account = account
    @actor = actor
    @filters = filters
    @search = search
  end

  def call
    leads = scope(@account.jrc_crm_leads).where(status: 'qualified')
    proposals = scope(@account.jrc_crm_proposals).where.not(sent_at: nil)
    if @search.present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(@search)}%"
      leads = leads.where('name ILIKE :q OR email ILIKE :q', q: query)
      proposals = proposals.where('title ILIKE :q OR proposal_number ILIKE :q', q: query)
    end

    {
      qualified_leads: leads.order(updated_at: :desc, id: :desc).map { |lead| lead.slice(:id, :name, :status) },
      sent_proposals: proposals.includes(:deal).order(sent_at: :desc, id: :desc).map do |proposal|
        proposal.slice(:id, :title, :proposal_number, :version_number, :status, :total_cents, :sent_at, :deal_id)
                .merge(pipeline_id: proposal.deal&.pipeline_id)
      end
    }
  end

  private

  def scope(relation)
    JrcCrm::CommercialMetricsScope.call(account: @account, actor: @actor, relation: relation, **@filters)
  end
end
