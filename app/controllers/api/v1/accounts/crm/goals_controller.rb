module Api::V1::Accounts::Crm
  class GoalsController < BaseController
    def index
      goals = crm_scope.jrc_crm_sales_goals.includes(:user).order(period_start: :desc)
      goals = goals.where(user_id: Current.user.id) unless crm_admin?
      render json: goals.map { |goal| serialize(goal) }
    end

    def create
      ensure_crm_admin!
      attributes = goal_params.to_h
      user_id = attributes.delete('user_id')
      user = user_id.present? ? crm_scope.users.find(user_id) : nil
      goal = crm_scope.jrc_crm_sales_goals.create!(attributes.merge(user: user))
      render json: serialize(goal), status: :created
    end

    def update
      ensure_crm_admin!
      goal = crm_scope.jrc_crm_sales_goals.find(params[:id])
      attributes = goal_params.to_h
      if attributes.key?('user_id')
        user_id = attributes.delete('user_id')
        attributes['user'] = user_id.present? ? crm_scope.users.find(user_id) : nil
      end
      goal.update!(attributes)
      render json: serialize(goal.reload)
    end

    private

    def goal_params
      params.require(:goal).permit(:user_id, :period_start, :period_end, :target_cents)
    end

    def serialize(goal)
      {
        id: goal.id,
        period_start: goal.period_start,
        period_end: goal.period_end,
        target_cents: goal.target_cents,
        user: goal.user && { id: goal.user.id, name: goal.user.name }
      }
    end
  end
end
