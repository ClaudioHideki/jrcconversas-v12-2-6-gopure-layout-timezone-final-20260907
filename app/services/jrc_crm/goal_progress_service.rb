module JrcCrm
  class GoalProgressService
    MONETARY_METRICS = %w[revenue mrr ticket].freeze
    ORDER_STATUSES = {
      'approved_orders' => %w[approved separating invoiced shipped completed],
      'completed_orders' => %w[completed],
      'invoiced_orders' => %w[invoiced shipped completed]
    }.freeze

    attr_reader :goal

    def initialize(goal:, user_id: nil)
      @goal = goal
      @user_id = user_id
    end

    def call
      target = monetary? ? target_cents : target_quantity
      realized = realized_value
      {
        target: target,
        realized: realized,
        attainment: percent(realized, target),
        remaining: [target.to_f - realized.to_f, 0].max.round,
        calculation_method: goal.calculation_method,
        criteria: effective_criteria,
        indicator_results: indicator_results,
        product_results: product_results
      }
    end

    def attainment_percent
      call[:attainment]
    end

    def product_results
      rows = Array(goal.product_targets)
      return [] if rows.empty?

      rows.filter_map do |row|
        product_id = (row['product_id'] || row[:product_id]).to_i
        next if product_id.zero?
        product = goal.account.jrc_crm_products.find_by(id: product_id)
        next unless product
        target = (row['target_cents'] || row[:target_cents] || 0).to_i
        realized = order_scope_for(product_id: product_id).joins(:order_items)
                   .where(jrc_crm_order_items: { product_id: product_id })
                   .sum('jrc_crm_sales_orders.total_cents')
        { product_id: product_id, name: product.name, target_cents: target, realized_cents: realized,
          percent: percent(realized, target) }
      end
    end

    private

    def monetary?
      MONETARY_METRICS.include?(goal.metric)
    end

    def target_cents
      if @user_id.present? && Array(goal.allocations).any?
        allocation = Array(goal.allocations).find { |row| (row['user_id'] || row[:user_id]).to_i == @user_id.to_i }
        return (allocation && (allocation['target_cents'] || allocation[:target_cents])).to_i
      end
      goal.target_cents.to_i
    end

    def target_quantity
      goal.target_quantity.to_i
    end

    def realized_value
      realized_for_metric(goal.metric)
    end

    def realized_for_metric(metric)
      if goal.calculation_method.to_s == 'won_deals'
        return deal_scope.sum(:value_cents) if metric.to_s == 'revenue'
        return deal_scope.count if metric.to_s == 'quantity'
        return deal_scope.where.not(contact_id: nil).distinct.count(:contact_id) if metric.to_s == 'customers'
        if metric.to_s == 'ticket'
          values = deal_scope.pluck(:value_cents)
          return values.empty? ? 0 : (values.sum.to_f / values.length).round
        end
      end

      case metric.to_s
      when 'revenue' then order_scope.sum(:total_cents)
      when 'mrr' then order_scope.sum(:monthly_cents)
      when 'quantity' then order_items_scope.sum(:quantity).to_f.round(3)
      when 'customers' then order_scope.where.not(contact_id: nil).distinct.count(:contact_id)
      when 'renewals' then contract_scope.where(status: 'renewed').count
      when 'conversion' then conversion_percent
      when 'ticket' then average_ticket
      else 0
      end
    end

    def indicator_results
      Array(goal.indicators).map do |row|
        data = row.with_indifferent_access
        metric = data[:metric].presence || infer_metric(data[:name])
        target = MONETARY_METRICS.include?(metric) ? data[:target_cents].to_i : data[:target_quantity].to_f
        realized = realized_for_metric(metric)
        { name: data[:name], metric: metric, target: target, realized: realized, weight: data[:weight].to_f,
          attainment: percent(realized, target) }
      end
    end

    def infer_metric(name)
      text = name.to_s.downcase
      return 'mrr' if text.include?('mrr') || text.include?('recorr')
      return 'customers' if text.include?('cliente')
      return 'renewals' if text.include?('renova')
      return 'conversion' if text.include?('convers')
      return 'ticket' if text.include?('ticket')
      'revenue'
    end

    def order_scope
      scope = order_scope_for(product_id: goal.product_id)
      statuses = ORDER_STATUSES.fetch(goal.calculation_method.to_s, ORDER_STATUSES['approved_orders'])
      scope.where(status: statuses)
    end

    def order_scope_for(product_id: nil)
      scope = goal.account.jrc_crm_sales_orders
      date_sql = 'COALESCE(jrc_crm_sales_orders.sold_at, jrc_crm_sales_orders.closed_at, jrc_crm_sales_orders.created_at) BETWEEN ? AND ?'
      scope = scope.where(date_sql, goal.period_start.beginning_of_day, goal.period_end.end_of_day)
      owner_id = @user_id.presence || goal.user_id
      scope = scope.where(owner_id: owner_id) if owner_id.present?
      scope = scope.where(business_unit_id: goal.business_unit_id) if goal.business_unit_id.present?
      if product_id.present?
        scope = scope.joins(:order_items).where(jrc_crm_order_items: { product_id: product_id }).distinct
      end
      apply_settings(scope)
    end

    def order_items_scope
      JrcCrm::OrderItem.where(sales_order_id: order_scope.select(:id))
    end

    def contract_scope
      scope = goal.account.jrc_crm_contracts.where(created_at: goal.period_start.beginning_of_day..goal.period_end.end_of_day)
      scope = scope.where(owner_id: (@user_id.presence || goal.user_id)) if @user_id.present? || goal.user_id.present?
      scope = scope.where(business_unit_id: goal.business_unit_id) if goal.business_unit_id.present?
      scope
    end

    def deal_scope
      scope = goal.account.jrc_crm_deals.where(status: 'won')
      scope = scope.where(updated_at: goal.period_start.beginning_of_day..goal.period_end.end_of_day)
      owner_id = @user_id.presence || goal.user_id
      scope = scope.where(owner_id: owner_id) if owner_id.present?
      scope
    end

    def conversion_percent
      scope = goal.account.jrc_crm_deals.where(updated_at: goal.period_start.beginning_of_day..goal.period_end.end_of_day)
      owner_id = @user_id.presence || goal.user_id
      scope = scope.where(owner_id: owner_id) if owner_id.present?
      closed = scope.where(status: %w[won lost]).count
      won = scope.where(status: 'won').count
      closed.zero? ? 0 : ((won.to_f / closed) * 100).round(2)
    end

    def average_ticket
      values = order_scope.pluck(:total_cents)
      values.empty? ? 0 : (values.sum.to_f / values.length).round
    end

    def apply_settings(scope)
      settings = (goal.settings || {}).with_indifferent_access
      statuses = settings[:statuses].presence || settings[:order_statuses].presence
      if statuses.present?
        allowed = Array(statuses).map(&:to_s)
        scope = scope.where(status: allowed)
      end
      if settings[:minimum_order_cents].present?
        scope = scope.where('jrc_crm_sales_orders.total_cents >= ?', settings[:minimum_order_cents].to_i)
      end
      scope
    end

    def effective_criteria
      { metric: goal.metric, period_start: goal.period_start, period_end: goal.period_end,
        user_id: @user_id.presence || goal.user_id, business_unit_id: goal.business_unit_id,
        product_id: goal.product_id, settings: goal.settings || {} }
    end

    def percent(value, target)
      return 0 if target.to_f <= 0
      ((value.to_f / target.to_f) * 100).round(1)
    end
  end
end
