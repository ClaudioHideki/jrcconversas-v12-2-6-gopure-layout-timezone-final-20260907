module Api::V1::Accounts::Crm
  class SalesOrdersController < BaseController
    before_action :set_order, only: [:show, :update, :pdf, :upload_attachments, :download_attachment]

    def index
      orders = visible_to_current_user(crm_scope.jrc_crm_sales_orders)
               .includes(:contact, :owner, :deal, :proposal, :order_items, :business_unit)
               .order(created_at: :desc)
      render json: orders.map { |order| serialize(order) }
    end

    def show
      render json: serialize(@order)
    end

    def preview
      render json: JrcCrm::OrderFinancials.new(attributes: order_params.to_h, items: submitted_items).call
    end

    def create
      order = nil
      JrcCrm::SalesOrder.transaction do
        order = if params[:proposal_id].present? && !params[:sales_order].present?
                proposal = crm_scope.jrc_crm_proposals.find(params[:proposal_id])
                JrcCrm::ProposalToOrderService.new(proposal: proposal, actor: Current.user).call
              else
                build_manual_order
              end
        sync_downstream!(order)
      end
      render json: serialize(order.reload), status: :created
    end

    def update
      @order.transaction do
        @order.update!(order_params)
        replace_items!(@order) if params.dig(:sales_order, :items).present?
        financial_keys = %w[items discount_cents shipping_cents installments_count snapshot]
        recalculate!(@order) if financial_keys.any? { |key| params[:sales_order].key?(key) }
        sync_downstream!(@order)
      end
      render json: serialize(@order.reload)
    end

    def pdf
      bytes = JrcCrm::OrderPdfService.new(@order).call
      send_data bytes, filename: "#{@order.order_number}.pdf", type: 'application/pdf', disposition: params[:download].present? ? 'attachment' : 'inline'
    end

    def upload_attachments
      uploads = Array(params[:files]).compact
      return render json: { message: 'Selecione ao menos um anexo.' }, status: :unprocessable_entity if uploads.empty?

      uploads.each { |file| @order.attachments.attach(file) }
      audit_order!(@order, 'order_attachment_uploaded', { filenames: uploads.map(&:original_filename) })
      render json: { attachments: attachment_rows(@order.reload) }, status: :created
    end

    def download_attachment
      attachment = @order.attachments.find(params[:attachment_id])
      send_data attachment.blob.download, filename: attachment.filename.to_s, type: attachment.content_type, disposition: 'attachment'
    end

    private

    def build_manual_order
      attrs = order_params
      owner_id = attrs.delete(:owner_id)
      owner = owner_id.present? ? crm_scope.users.find(owner_id) : Current.user
      order = nil
      JrcCrm::SalesOrder.transaction do
        order = crm_scope.jrc_crm_sales_orders.create!(attrs.merge(owner: owner, source_type: 'manual', snapshot: order_snapshot))
        replace_items!(order)
        recalculate!(order)
      end
      order
    end

    def set_order
      @order = visible_to_current_user(crm_scope.jrc_crm_sales_orders).find(params[:id])
    end

    def order_params
      params.require(:sales_order).permit(
        :deal_id, :proposal_id, :contact_id, :owner_id, :business_unit_id, :status,
        :products_cents, :shipping_cents, :discount_cents, :total_cents, :monthly_cents,
        :payment_condition, :payment_method, :down_payment_cents, :installments_count,
        :sold_at, :closed_at, :notes,
        snapshot: {}
      )
    end

    def order_snapshot
      raw = params.dig(:sales_order, :snapshot)
      raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : (raw || {})
    end

    def replace_items!(order)
      order.order_items.destroy_all
      calculator = JrcCrm::OrderFinancials.new(attributes: order.attributes, items: [])
      submitted_items.each do |item|
        order.order_items.create!(calculator.normalize_item(item.with_indifferent_access))
      end
    end

    def submitted_items
      Array(params.dig(:sales_order, :items)).map do |item|
        item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h
      end
    end

    def recalculate!(order)
      result = JrcCrm::OrderFinancials.new(attributes: order.attributes, items: order.order_items.map(&:attributes)).call
      snapshot = (order.snapshot || {}).merge('financial_version' => 1, 'taxes_cents' => result[:taxes_cents],
                                             'installments' => result[:installments])
      order.update!(result.slice(:products_cents, :monthly_cents, :shipping_cents, :discount_cents, :total_cents, :installments_count)
                     .merge(snapshot: snapshot))
    end

    def sync_downstream!(order)
      JrcCrm::OrderWorkflowSyncService.new(order: order.reload, actor: Current.user).call
    end


    def attachment_rows(order)
      order.attachments.map do |attachment|
        { id: attachment.id, filename: attachment.filename.to_s, content_type: attachment.content_type,
          byte_size: attachment.byte_size, created_at: attachment.created_at }
      end
    end

    def audit_order!(order, event_type, metadata)
      JrcCrm::AuditEvent.create!(account_id: crm_scope.id, actor_type: 'User', actor_id: Current.user&.id,
        event_type: event_type, resource_type: 'JrcCrm::SalesOrder', resource_id: order.id,
        from_value: {}, to_value: {}, metadata: metadata.merge(source: 'crm_orders'))
    rescue StandardError => e
      Rails.logger.warn("JRC CRM order audit failed: #{e.message}")
    end

    def serialize(order)
      snap = order.snapshot || {}
      {
        id: order.id, order_number: order.order_number, status: order.status,
        total_cents: order.total_cents, products_cents: order.products_cents,
        shipping_cents: order.shipping_cents, discount_cents: order.discount_cents,
        monthly_cents: order.monthly_cents, payment_condition: order.payment_condition,
        payment_method: order.payment_method, down_payment_cents: order.down_payment_cents,
        installments_count: order.installments_count, sold_at: order.sold_at,
        notes: order.notes, snapshot: snap,
        contact: order.contact && { id: order.contact.id, name: order.contact.name, email: order.contact.email, phone_number: order.contact.phone_number },
        owner: { id: order.owner.id, name: order.owner.name },
        business_unit: order.business_unit && { id: order.business_unit.id, name: order.business_unit.name, code: order.business_unit.code },
        deal: order.deal && { id: order.deal.id, title: order.deal.title },
        proposal: order.proposal && { id: order.proposal.id, proposal_number: order.proposal.proposal_number },
        items: order.order_items.map { |i| { id: i.id, product_id: i.product_id, name: i.name, quantity: i.quantity, unit_cents: i.unit_cents, discount_cents: i.discount_cents, one_time_cents: i.one_time_cents, recurring_cents: i.recurring_cents, snapshot: i.snapshot } },
        attachments: attachment_rows(order),
        created_at: order.created_at, updated_at: order.updated_at
      }
    end
  end
end
