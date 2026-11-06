class JrcCrm::OrderDeletionService
  class Conflict < StandardError; end

  def initialize(account:, actor:, ids:, reason:)
    @account = account
    @actor = actor
    @ids = Array(ids).map(&:to_s).uniq.sort
    @reason = reason.to_s.strip
  end

  def preview
    authorize!
    orders = scoped_orders.to_a
    plan = JrcCrm::OrderDeletionInventory.new(account: @account, actor: @actor, orders: orders).call
    plan.merge(token: verifier.generate(identity.merge('fingerprint' => plan[:fingerprint]), expires_in: 10.minutes, purpose: 'execute'),
               cancellation_requests: plan[:rows].select { |r| r[:type] == 'orders' && r[:action] == 'preserve' }.map { |r| r[:reference] })
  end

  def execute(token:, confirmed:, confirmation:)
    authorize!
    signed = verifier.verified(token.to_s, purpose: 'execute')
    raise Conflict, 'Prévia inválida/expirada; analise novamente os vínculos.' unless signed && identity.all? { |key, value| signed[key] == value }
    raise Conflict, 'Confirmação explícita obrigatória.' unless confirmed == true

    JrcCrm::SalesOrder.transaction do
      # Serialize with native approval creation, whose resource references are polymorphic.
      JrcApprovals::Ledger.lock!(@account.id, 'publication')
      authorize!(lock: true)
      # Same source-first order as ProposalToOrderService; then FK parents before children.
      JrcCrm::Proposal.where(id: scoped_orders.select(:proposal_id)).order(:id).lock.load
      orders = scoped_orders.order(:id).lock.to_a
      inventory = JrcCrm::OrderDeletionInventory.new(account: @account, actor: @actor, orders: orders, lock: true)
      plan = inventory.call
      if plan[:blocked] || plan[:fingerprint] != signed['fingerprint'] || confirmation != plan[:confirmation]
        raise Conflict, 'Os vínculos ou a confirmação mudaram. Gere e confira uma nova prévia.'
      end

      perform_deletion(orders, inventory, plan)
    end
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, ActiveRecord::RecordNotDestroyed,
         ActiveRecord::Deadlocked, ActiveRecord::SerializationFailure, ActiveRecord::LockWaitTimeout
    raise Conflict, 'A operação foi revertida por vínculo/concorrência. Analise novamente a prévia.'
  end

  private

  def perform_deletion(orders, inventory, plan)
    receipts = orders.map { |order| receipt_for(order, inventory, plan) }
    cancel_pending_approvals(inventory, receipts.first)
    delete_permitted(inventory)
    deleted, retained = orders.partition(&:destroyed?)
    requests = retained.map { |order| request_cancellation(order, receipts.find { |r| r.resource_id == order.id }) }
    { removed_ids: deleted.map(&:id), retained_ids: retained.map(&:id), receipt_ids: receipts.map(&:id),
      cancellation_request_ids: requests.map(&:id), status: retained.any? ? 'retention_required' : 'deleted' }
  end

  def receipt_for(order, inventory, plan)
    deleted = inventory.nodes.fetch([order.class.table_name, order.id])[:action] == 'delete'
    @account.jrc_crm_audit_events.create!(actor_type: @actor.class.name, actor_id: @actor.id,
                                          event_type: 'order_deletion_executed', resource_type: order.class.name, resource_id: order.id,
                                          from_value: order.status, to_value: deleted ? 'deleted' : 'retained',
                                          metadata: { order_number: order.order_number, reason: @reason, total_cents: order.total_cents,
                                                      plan_fingerprint: plan[:fingerprint], scope: plan[:rows], proposal_id: order.proposal_id,
                                                      financial_actions: 'Nenhum estorno, cancelamento fiscal ou distrato externo executado.' })
  end

  def authorize!(lock: false)
    memberships = @account.account_users
    memberships = memberships.lock('FOR SHARE') if lock
    member = memberships.find_by!(user_id: @actor.id)
    raise Pundit::NotAuthorizedError unless member.administrator? && member.permissions.include?('jrc_crm')
    unless @ids.any? && @ids.size <= 20 && @ids.all? { |id| id.match?(/\A[1-9]\d*\z/) } && @reason.length.between?(3, 1000)
      raise JrcCrm::CommercialFinancials::InvalidTerms, 'Selecione de 1 a 20 pedidos e informe motivo de 3 a 1.000 caracteres.'
    end
    raise ActiveRecord::RecordNotFound unless scoped_orders.count == @ids.size
  end

  def scoped_orders
    JrcCrm::OrganizationalVisibility.new(account: @account, user: @actor,
                                         relation: @account.jrc_crm_sales_orders.where(id: @ids)).call
  end

  def identity
    { 'account_id' => @account.id, 'actor_id' => @actor.id, 'ids' => @ids, 'reason_digest' => Digest::SHA256.hexdigest(@reason) }
  end

  def verifier
    Rails.application.message_verifier('jrc-order-deletion-v1')
  end

  def cancel_pending_approvals(inventory, receipt)
    inventory.nodes.values.select { |n| n[:action] == 'cancel' }.each do |node|
      request = node[:record]
      request.update!(state: 'canceled')
      JrcApprovals::AuditEvent.create!(account: @account, actor: @account.account_users.find_by!(user_id: @actor.id),
                                       request_id: request.id, event_type: 'request_canceled', correlation_key: "order-deletion:#{receipt.id}:#{request.id}",
                                       data: { request_id: request.id, reason: @reason, deletion_receipt_id: receipt.id })
    end
  end

  def delete_permitted(inventory)
    remaining = inventory.nodes.values.select { |n| n[:action] == 'delete' }
    until remaining.empty?
      leaf = remaining.find do |parent|
        remaining.none? do |child|
          child != parent && inventory.referenced_by?(parent, child)
        end
      end
      raise Conflict, 'Vínculo circular exige revisão; nenhuma exclusão foi confirmada.' unless leaf

      leaf[:record].destroy!
      remaining.delete(leaf)
    end
  end

  def request_cancellation(order, receipt)
    existing = order.backoffice_requests.where(request_kind: 'cancellation', status: JrcCrm::BackofficeRequest::ACTIVE_STATUSES).order(:id).first
    return existing if existing

    order.backoffice_requests.create!(account: @account, business_unit: order.business_unit, owner: @actor, requested_by: @actor,
                                      contact: order.contact, request_kind: 'cancellation', stage: 'request', status: 'pending',
                                      title: "Revisar exclusão/cancelamento #{order.order_number}", description: @reason,
                                      metadata: { source: 'administrative_deletion', deletion_receipt_id: receipt.id,
                                                  external_reversal_executed: false, retention_review_required: true })
  end
end
