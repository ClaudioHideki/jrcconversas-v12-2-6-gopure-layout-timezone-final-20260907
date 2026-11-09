module JrcCrm
  class MetricsCalculatorService
    def initialize(account:, start_date:, end_date:, pipeline_id: nil, **context)
      @account = account
      @actor = context.fetch(:actor, nil)
      raise ArgumentError, 'Unknown metrics context' unless (context.keys - [:actor, :owner_id]).empty?

      @pipeline_id = pipeline_id
      @owner_id = context.fetch(:owner_id, nil)
      @start_date = start_date&.beginning_of_day
      @end_date = end_date&.end_of_day
    end

    def call
      metrics.merge(funnel_records: funnel_records)
    end

    private

    def metrics
      {
        total_leads: count_leads,
        leads_count: count_leads,
        new_leads_count: count_new_leads,
        open_deals: count_open_deals,
        open_deals_count: count_open_deals,
        pipeline_value_cents: calculate_pipeline_value,
        won_revenue_cents: calculate_won_revenue,
        weighted_value_cents: calculate_weighted_value,
        conversion_rate: calculate_conversion_rate,
        avg_ticket_cents: calculate_avg_ticket,
        average_ticket_cents: calculate_avg_ticket,
        closed_won_count: count_won_deals,
        closed_lost_count: count_lost_deals,
        overdue_activities_count: overdue_activities_count,
        stalled_deals_count: stalled_deals_count,
        funnel_stages: funnel_stages,
        commercial_summary: commercial_summary
      }
    end

    def funnel_records
      JrcCrm::FunnelRecordsService.new(
        account: @account, actor: @actor,
        filters: { owner_id: @owner_id, pipeline_id: @pipeline_id, start_date: @start_date, end_date: @end_date }
      ).call
    end

    def commercial_summary
      leads = metrics_scope(@account.jrc_crm_leads)
      proposals = metrics_scope(@account.jrc_crm_proposals)
      orders = metrics_scope(@account.jrc_crm_sales_orders).where("NOT (snapshot ? 'removal')")
      active_orders = orders.where(status: JrcCrm::SalesOrder::COMMERCIAL_ACTIVE_STATUSES)
      # Preserve provenance even if a former internal actor was deleted. Legacy
      # public events have the native public-controller description, not metadata.
      public_acceptances = JrcCrm::ProposalEvent.where(account_id: @account.id, event_type: 'accepted')
                                                .where("metadata ->> 'acceptance_origin' = :origin OR description = :legacy",
                                                       origin: 'public_link', legacy: 'Proposta aceita pelo cliente com evidência digital')
      signed = proposals.where(status: 'accepted', id: public_acceptances.select(:proposal_id))
                        .where.not(accepted_at: nil).where.not(accepted_by_name: [nil, '']).where.not(accepted_by_document: [nil, ''])
      {
        leads: leads.group(:status).count,
        deals: %w[open won lost].index_with do |status|
          scope = base_deals.where(status: status)
          { count: scope.count, value_cents: scope.sum(:value_cents) }
        end,
        proposals_sent_count: proposals.where.not(sent_at: nil).count,
        signed_proposals: { count: signed.count, value_cents: signed.sum(:total_cents) },
        orders: { total_count: orders.count, active_count: active_orders.count,
                  pending_count: orders.where(status: %w[draft pending]).count,
                  revenue_cents: active_orders.sum(:total_cents),
                  statuses: orders.group(:status).count }
      }
    end

    def base_deals
      metrics_scope(@account.jrc_crm_deals)
    end

    def metrics_scope(relation, owner_column: :owner_id)
      JrcCrm::CommercialMetricsScope.call(account: @account, actor: @actor, relation: relation, owner_id: @owner_id,
                                          owner_column: owner_column, pipeline_id: @pipeline_id, start_date: @start_date, end_date: @end_date)
    end

    def count_leads
      metrics_scope(@account.jrc_crm_leads).count
    end

    def count_new_leads
      metrics_scope(@account.jrc_crm_leads).where(status: 'new').count
    end

    def count_open_deals
      base_deals.where(status: 'open').count
    end

    def count_won_deals
      base_deals.where(status: 'won').count
    end

    def count_lost_deals
      base_deals.where(status: 'lost').count
    end

    def calculate_pipeline_value
      base_deals.where(status: 'open').sum(:value_cents)
    end

    def calculate_won_revenue
      base_deals.where(status: 'won').sum(:value_cents)
    end

    def calculate_weighted_value
      # Weighted value = value * probability
      # Simplified via SQL sum
      base_deals.where(status: 'open').joins(:stage).sum('jrc_crm_deals.value_cents * (jrc_crm_stages.probability / 100.0)').round
    end

    def calculate_conversion_rate
      total_closed = count_won_deals + count_lost_deals
      return 0 if total_closed.zero?

      ((count_won_deals.to_f / total_closed) * 100).round(2)
    end

    def calculate_avg_ticket
      won_count = count_won_deals
      return 0 if won_count.zero?

      Rational(calculate_won_revenue, won_count).round
    end

    def overdue_activities_count
      activities = metrics_scope(@account.jrc_crm_activities, owner_column: :user_id).where(completed_at: nil).where(
        'due_at < ?', Time.current
      )
      activities = activities.where(user_id: @owner_id) if @owner_id.present?
      activities.count
    end

    def stalled_deals_count
      base_deals.where(status: 'open').where('updated_at < ?', 7.days.ago).count
    end

    def funnel_stages
      pipelines = @account.jrc_crm_pipelines.active
      pipelines = pipelines.where(id: @pipeline_id) if @pipeline_id.present?
      counts = base_deals.group(:stage_id).count
      values = base_deals.group(:stage_id).sum(:value_cents)
      open = base_deals.where(status: 'open')
      open_counts = open.group(:stage_id).count
      open_values = open.group(:stage_id).sum(:value_cents)
      maximum = [counts.values.max.to_i, 1].max
      @account.jrc_crm_stages.where(pipeline_id: pipelines.select(:id)).active.includes(:pipeline)
              .joins(:pipeline)
              .order('jrc_crm_pipelines.position', 'jrc_crm_pipelines.id', 'jrc_crm_stages.position', 'jrc_crm_stages.id').map do |stage|
        {
          id: stage.id,
          name: stage.name,
          key: stage.key,
          is_won: stage.is_won,
          is_lost: stage.is_lost,
          pipeline_id: stage.pipeline_id,
          pipeline_name: stage.pipeline.name,
          deals_count: counts[stage.id].to_i,
          open_deals_count: open_counts[stage.id].to_i,
          open_value_cents: open_values[stage.id].to_i,
          value_cents: values[stage.id].to_i,
          percentage: ((counts[stage.id].to_f / maximum) * 100).round
        }
      end
    end
  end
end
