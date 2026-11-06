module JrcCrm
  class StageSerializer
    def initialize(stage)
      @stage = stage
    end

    def as_json(_options = {})
      {
        id: @stage.id,
        name: @stage.name,
        pipeline_id: @stage.pipeline_id,
        pipeline_name: @stage.pipeline.name,
        key: @stage.key,
        position: @stage.position,
        color: @stage.color,
        probability: @stage.probability,
        is_terminal: @stage.is_terminal,
        is_won: @stage.is_won,
        is_lost: @stage.is_lost,
        active: @stage.active,
        deals_count: @stage.deals.where(status: 'open').count,
        deals_value_cents: @stage.deals.where(status: 'open').sum(:value_cents)
      }
    end
  end
end
