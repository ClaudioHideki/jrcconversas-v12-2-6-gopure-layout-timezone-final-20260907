module JrcCrm
  class CommissionRulesEngine
    def initialize(rules:, sale:, attainment_percent: nil, share_percent: 100)
      @rules = (rules || {}).with_indifferent_access
      @sale = (sale || {}).with_indifferent_access
      @attainment_percent = attainment_percent.to_d if attainment_percent.present?
      @share_percent = share_percent.to_d
    end

    def call
      base = commission_base
      rate, tier = selected_rate(base)
      gross = (base * rate / 100).round
      shared = (gross * @share_percent / 100).round
      bonus = bonus_cents(base, shared)
      total = shared + bonus
      {
        base_cents: base,
        rate_percent: rate.to_f,
        share_percent: @share_percent.to_f,
        tier_basis: tier_basis,
        selected_tier: tier,
        attainment_percent: @attainment_percent&.to_f,
        gross_commission_cents: gross,
        bonus_cents: bonus,
        commission_cents: total,
        calculation: calculation_memory(base, rate, tier, bonus, total)
      }
    end

    private

    def commission_base
      key = @rules[:base].presence || 'total_cents'
      case key
      when 'monthly_cents' then @sale[:monthly_cents].to_i
      when 'received_cents' then @sale[:received_cents].to_i
      when 'margin_cents' then @sale[:margin_cents].to_i
      else @sale[:total_cents].to_i
      end
    end

    def tier_basis
      @rules[:tier_basis].presence || 'sales_value'
    end

    def selected_rate(base)
      value = tier_basis == 'goal_attainment' ? @attainment_percent.to_d : base.to_d
      tiers = Array(@rules[:tiers]).map { |row| row.with_indifferent_access }
      tier = tiers.sort_by { |row| minimum_for(row) }.reverse.find do |row|
        min = minimum_for(row)
        max = maximum_for(row)
        value >= min && (max.nil? || value <= max)
      end
      [(tier&.dig(:rate_percent) || @rules[:rate_percent] || 0).to_d, tier&.to_h]
    end

    def minimum_for(row)
      tier_basis == 'goal_attainment' ? (row[:min_percent] || 0).to_d : (row[:min_cents] || 0).to_d
    end

    def maximum_for(row)
      value = tier_basis == 'goal_attainment' ? row[:max_percent] : row[:max_cents]
      value.present? ? value.to_d : nil
    end

    def bonus_cents(base, shared)
      bonuses = Array(@rules[:bonuses]).map { |row| row.with_indifferent_access }
      bonuses.sum do |bonus|
        threshold = (bonus[:attainment_percent] || 0).to_d
        next 0 unless @attainment_percent.present? && @attainment_percent >= threshold
        if bonus[:amount_cents].present?
          bonus[:amount_cents].to_i
        else
          (shared * (bonus[:percent] || 0).to_d / 100).round
        end
      end
    end

    def calculation_memory(base, rate, tier, bonus, total)
      { base_kind: @rules[:base].presence || 'total_cents', base_cents: base, tier_basis: tier_basis,
        selected_tier: tier, rate_percent: rate.to_f, share_percent: @share_percent.to_f,
        attainment_percent: @attainment_percent&.to_f, bonus_cents: bonus, commission_cents: total }
    end
  end
end
