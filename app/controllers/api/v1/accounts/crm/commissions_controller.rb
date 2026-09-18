module Api::V1::Accounts::Crm
  class CommissionsController < BaseController
    def index
      scope = crm_scope.jrc_crm_sales_commissions.includes(:user, :sales_order).order(created_at: :desc)
      scope = scope.where(user_id: Current.user.id) unless crm_admin?
      render json: scope.map { |commission| serialize(commission) }
    end

    def create
      ensure_crm_admin!
      attributes = commission_params.to_h
      order = crm_scope.jrc_crm_sales_orders.find(attributes.delete('sales_order_id'))
      user = crm_scope.users.find(attributes.delete('user_id'))
      commission = crm_scope.jrc_crm_sales_commissions.create!(attributes.merge(sales_order: order, user: user))
      render json: serialize(commission), status: :created
    end

    def update
      ensure_crm_admin!
      commission = crm_scope.jrc_crm_sales_commissions.find(params[:id])
      commission.update!(commission_params.except(:sales_order_id, :user_id))
      render json: serialize(commission.reload)
    end

    private

    def commission_params
      params.require(:commission).permit(:sales_order_id, :user_id, :base_cents, :rate_percent, :status, :released_at, :paid_at, :notes)
    end

    def serialize(commission)
      {
        id: commission.id,
        status: commission.status,
        base_cents: commission.base_cents,
        rate_percent: commission.rate_percent,
        commission_cents: commission.commission_cents,
        user: { id: commission.user.id, name: commission.user.name },
        order: {
          id: commission.sales_order.id,
          order_number: commission.sales_order.order_number,
          total_cents: commission.sales_order.total_cents
        }
      }
    end
  end
end
