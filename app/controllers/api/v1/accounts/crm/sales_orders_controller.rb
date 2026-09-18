module Api::V1::Accounts::Crm
  class SalesOrdersController < BaseController
    before_action :set_order, only: [:show, :update]
    def index
      orders = visible_to_current_user(crm_scope.jrc_crm_sales_orders).includes(:contact, :owner, :deal, :proposal).order(created_at: :desc)
      render json: orders.map { |o| serialize(o) }
    end
    def show; render json: serialize(@order); end
    def create
      if params[:proposal_id].present?
        proposal = crm_scope.jrc_crm_proposals.find(params[:proposal_id])
        order = JrcCrm::ProposalToOrderService.new(proposal: proposal, actor: Current.user).call
      else
        order = crm_scope.jrc_crm_sales_orders.create!(order_params.merge(owner: Current.user))
      end
      render json: serialize(order), status: :created
    end
    def update
      @order.update!(order_params)
      render json: serialize(@order.reload)
    end
    private
    def set_order; @order = visible_to_current_user(crm_scope.jrc_crm_sales_orders).find(params[:id]); end
    def order_params
      params.require(:sales_order).permit(:deal_id,:proposal_id,:contact_id,:owner_id,:status,:products_cents,:shipping_cents,:discount_cents,:total_cents,:monthly_cents,:payment_condition,:payment_method,:down_payment_cents,:installments_count,:sold_at,:closed_at,:notes)
    end
    def serialize(o)
      { id:o.id, order_number:o.order_number, status:o.status, total_cents:o.total_cents, products_cents:o.products_cents, shipping_cents:o.shipping_cents, monthly_cents:o.monthly_cents, payment_condition:o.payment_condition, payment_method:o.payment_method, down_payment_cents:o.down_payment_cents, installments_count:o.installments_count, sold_at:o.sold_at, contact:o.contact && {id:o.contact.id,name:o.contact.name}, owner:{id:o.owner.id,name:o.owner.name}, deal:{id:o.deal.id,title:o.deal.title}, proposal:o.proposal && {id:o.proposal.id,proposal_number:o.proposal.proposal_number}, created_at:o.created_at }
    end
  end
end
