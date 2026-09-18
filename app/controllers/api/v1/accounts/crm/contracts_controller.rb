module Api::V1::Accounts::Crm
  class ContractsController < BaseController
    before_action :set_contract, only: [:update, :pdf]

    def index
      rows=visible_to_current_user(crm_scope.jrc_crm_contracts).includes(:contact,:owner,:sales_order,:deal).order(created_at: :desc)
      render json: rows.as_json(include:{contact:{only:[:id,:name]},owner:{only:[:id,:name]},sales_order:{only:[:id,:order_number]},deal:{only:[:id,:title]}})
    end
    def create
      order=crm_scope.jrc_crm_sales_orders.find(params.dig(:contract,:sales_order_id))
      c=crm_scope.jrc_crm_contracts.create!(contract_params.merge(deal:order.deal,contact:order.contact,owner:order.owner))
      render json:c,status: :created
    end
    def update
      @contract.update!(contract_params); render json:@contract
    end
    def pdf
      pdf_data = JrcCrm::ContractPdfService.new(@contract).call
      send_data pdf_data,
                filename: "#{@contract.contract_number.parameterize.presence || "contrato-#{@contract.id}"}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end
    private
    def set_contract
      @contract = visible_to_current_user(crm_scope.jrc_crm_contracts).includes(
        :contact, :owner, :deal, { sales_order: { order_items: :product } }, { contract_items: :product }
      ).find(params[:id])
    end
    def contract_params; params.require(:contract).permit(:sales_order_id,:status,:starts_on,:ends_on,:term_months,:renewal_type,:adjustment_index,:monthly_cents,:one_time_cents,:next_adjustment_on,:notes); end
  end
end
