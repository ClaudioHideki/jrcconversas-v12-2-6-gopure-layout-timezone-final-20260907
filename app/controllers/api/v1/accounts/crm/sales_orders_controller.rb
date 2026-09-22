module Api::V1::Accounts::Crm
  class SalesOrdersController < BaseController
    rescue_from ArgumentError do |error|
      render json: { message: error.message }, status: :unprocessable_entity
    end
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
                proposal = visible_to_current_user(crm_scope.jrc_crm_proposals).find(params[:proposal_id])
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
        attrs = order_params
        attrs[:snapshot] = @order.snapshot.merge(attrs[:snapshot]) if attrs[:snapshot]
        @order.update!(attrs)
        replace_items!(@order) if params[:sales_order].key?(:items)
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
      attributes = params.require(:sales_order).permit(
        :deal_id, :proposal_id, :contact_id, :owner_id, :business_unit_id, :status,
        :shipping_cents, :discount_cents,
        :payment_condition, :payment_method, :down_payment_cents, :installments_count,
        :sold_at, :closed_at, :notes,
        snapshot: {}
      )
      { deal_id: crm_scope.jrc_crm_deals, proposal_id: crm_scope.jrc_crm_proposals }.each do |key, scope|
        visible_to_current_user(scope).find(attributes[key]) if attributes[key].present?
      end
      crm_scope.contacts.find(attributes[:contact_id]) if attributes[:contact_id].present?
      crm_scope.jrc_crm_business_units.find(attributes[:business_unit_id]) if attributes[:business_unit_id].present?
      if attributes[:owner_id].present?
        crm_scope.users.find(attributes[:owner_id])
        raise Pundit::NotAuthorizedError if !crm_admin? && attributes[:owner_id].to_i != Current.user.id
      end
      attributes
    end

    def order_snapshot
      raw = params.dig(:sales_order, :snapshot)
      raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : (raw || {})
    end

    def replace_items!(order)
      items = submitted_items
      order.order_items.destroy_all
      calculator = JrcCrm::OrderFinancials.new(attributes: order.attributes, items: [])
      items.each do |item|
        order.order_items.create!(calculator.normalize_item(item.with_indifferent_access))
      end
    end

    def submitted_items
      Array(params.dig(:sales_order, :items)).map do |item|
        row = (item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item.to_h).with_indifferent_access
        existing = @order&.order_items&.find_by(id: row[:id]) if row[:id].present?
        if row[:product_id].present?
          product = crm_scope.jrc_crm_products.find(row[:product_id])
          row[:name] = product.name if row[:name].blank?
          row[:snapshot] = { billing_model: product.billing_model, setup_fee_cents: product.setup_fee_cents,
                             contract_term_months: product.contract_term_months, unit_name: product.sales_unit,
                             requires_implementation: product.requires_implementation }.with_indifferent_access.merge(row[:snapshot] || {})
          # An order cannot bypass a product's operational requirement by sending false.
          # Persisted items retain the setting agreed when the order was created.
          row[:snapshot][:requires_implementation] = existing && existing.product_id == product.id ?
            ActiveModel::Type::Boolean.new.cast(existing.snapshot['requires_implementation']) : product.requires_implementation
        end
        row
      end
    end

    def recalculate!(order)
      JrcCrm::OrderFinancials.recalculate!(order)
    end

    def sync_downstream!(order)
      order.validate_implementation! unless order.draft? || order.canceled?
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
        communication_available: false,
        next_activity: visible_to_current_user(order.activities, owner_column: :user_id).pending.order(:due_at).first&.then { |activity| JrcCrm::ActivitySerializer.new(activity).as_json },
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
