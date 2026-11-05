class Api::V1::Accounts::Crm::ReportsController < Api::V1::Accounts::Crm::BaseController
  before_action :set_report_filters

  def index
    render json: {
      period: { start_date: @start_date, end_date: @end_date },
      summary: summary,
      leads_by_status: lead_status_counts,
      leads_by_source: group_count(leads_scope, :source),
      deals_by_status: group_count(deals_scope, :status),
      proposals_by_status: group_count(proposals_scope, :status),
      revenue_by_owner: revenue_by_owner,
      revenue_basis: JrcCrm::ProposalProfile.gopure?(crm_scope) ? 'active_orders' : 'won_deals',
      activities: activity_metrics
    }
  end

  private

  def set_report_filters
    @start_date, @end_date = commercial_metric_dates
    @owner_id = crm_admin? ? params[:owner_id] : Current.user.id
  end

  def summary
    crm_metrics(
      pipeline_id: params[:pipeline_id],
      owner_id: @owner_id,
      start_date: @start_date,
      end_date: @end_date
    ).call
  end

  def leads_scope
    report_scope(:jrc_crm_leads)
  end

  def deals_scope
    report_scope(:jrc_crm_deals)
  end

  def proposals_scope
    report_scope(:jrc_crm_proposals)
  end

  def activity_metrics
    scope = report_scope(:jrc_crm_activities, owner_column: :user_id)
    scope = scope.where(user_id: @owner_id) if @owner_id.present?
    { completed: scope.completed.count, pending: scope.pending.count, overdue: scope.overdue.count }
  end

  def revenue_by_owner
    totals = if JrcCrm::ProposalProfile.gopure?(crm_scope)
               report_scope(:jrc_crm_sales_orders).where("NOT (snapshot ? 'removal')")
                                                   .where(status: JrcCrm::SalesOrder::COMMERCIAL_ACTIVE_STATUSES)
                                                   .group(:owner_id).sum(:total_cents)
             else
               deals_scope.won_deals.group(:owner_id).sum(:value_cents)
             end
    items = User.where(id: totals.keys).pluck(:id, :name).map do |id, name|
      { owner_id: id, owner_name: name, value_cents: totals[id] }
    end
    items.sort_by { |item| -item[:value_cents] }
  end

  def group_count(scope, field)
    items = scope.group(field).count.map do |name, count|
      { name: name.presence || 'unknown', count: count }
    end
    items.sort_by { |item| -item[:count] }
  end

  def lead_status_counts
    totals = leads_scope.group(:status).count.each_with_object(Hash.new(0)) do |(status, count), result|
      public_status = %w[unqualified lost].include?(status) ? 'discarded' : status
      result[public_status.presence || 'unknown'] += count
    end
    totals.map { |name, count| { name: name, count: count } }.sort_by { |item| -item[:count] }
  end

  def report_scope(association, owner_column: :owner_id)
    JrcCrm::CommercialMetricsScope.call(account: crm_scope, actor: Current.user, relation: crm_scope.public_send(association),
                                       owner_id: @owner_id, owner_column: owner_column, pipeline_id: params[:pipeline_id],
                                       start_date: @start_date, end_date: @end_date)
  end
end
