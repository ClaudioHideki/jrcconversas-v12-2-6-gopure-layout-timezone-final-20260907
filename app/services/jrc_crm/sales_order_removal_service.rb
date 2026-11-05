class JrcCrm::SalesOrderRemovalService
  def initialize(account:, actor:, orders:, reason:)
    @account, @actor, @orders, @reason = account, actor, orders, reason.to_s.strip
  end

  def call
    raise Pundit::NotAuthorizedError unless @account.account_users.find_by!(user: @actor).administrator?
    raise JrcCrm::CommercialFinancials::InvalidTerms, 'Informe o motivo da exclusão.' if @reason.blank?

    JrcCrm::SalesOrder.transaction do
      @orders.order(:id).lock.each do |order|
        next if order.snapshot['removal'].present?

        if order.contracts.exists? || order.invoices.exists? || order.commissions.exists? ||
           order.backoffice_requests.exists? || %w[invoiced shipped completed].include?(order.status)
          raise JrcCrm::CommercialFinancials::InvalidTerms,
                "#{order.order_number}: há vínculos operacionais ou financeiros. Utilize o fluxo de cancelamento responsável."
        end
        previous_status = order.status
        removal = { 'at' => Time.current.iso8601, 'actor_id' => @actor.id, 'reason' => @reason, 'previous_status' => previous_status }
        order.update!(status: 'canceled', snapshot: order.snapshot.merge('removal' => removal))
        @account.jrc_crm_audit_events.create!(actor_type: @actor.class.name, actor_id: @actor.id,
                                             resource_type: order.class.name, resource_id: order.id,
                                             event_type: 'order_removed', from_value: previous_status, to_value: 'canceled',
                                             metadata: removal.merge('order_number' => order.order_number, 'status' => order.status))
      end
    end
  end
end
