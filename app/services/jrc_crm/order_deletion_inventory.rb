# Read-only inventory. Unknown links retain their parent; no generic cascade deletes.
class JrcCrm::OrderDeletionInventory
  LABELS = {
    'orders' => 'Pedido', 'items' => 'Item do pedido', 'contracts' => 'Contrato', 'contract_items' => 'Item contratual',
    'invoices' => 'Faturamento / cobrança', 'payments' => 'Pagamento', 'commissions' => 'Comissão', 'backoffice' => 'Backoffice',
    'activities' => 'Atividade', 'projects' => 'Projeto', 'proposals' => 'Proposta de origem', 'proposal_items' => 'Item da proposta',
    'proposal_events' => 'Histórico da proposta', 'audit' => 'Auditoria', 'approvals' => 'Alçada',
    'approval_decisions' => 'Decisão de alçada', 'approval_audit' => 'Auditoria da alçada', 'documents' => 'Documento'
  }.freeze
  EVIDENCE_FIELDS = %w[request_kind stage signed_at paid_at issued_on reconciliation_status sales_order_id invoice_id
                       contract_id quantity unit_cents discount_cents one_time_cents recurring_cents].freeze
  LIMIT = 1000
  attr_reader :nodes, :issues

  def initialize(account:, actor:, orders:, lock: false)
    @account = account
    @actor = actor
    @orders = orders
    @lock = lock
    @nodes = {}
    @issues = []
  end

  def call
    collect
    references.protect!
    protect_financial_evidence
    protect_approvals
    rows = nodes.values.map { |node| public_row(node) }.sort_by { |row| [row[:type], row[:id]] }
    { rows: rows, blocked: issues.any?, issues: issues.uniq,
      counts: rows.group_by { |row| row[:action] }.transform_values(&:length),
      confirmation: @orders.size == 1 ? "EXCLUIR #{@orders.first.order_number}" : "EXCLUIR #{@orders.size} PEDIDOS",
      fingerprint: Digest::SHA256.hexdigest(nodes.sort.map { |key, node| [key, node[:record].attributes, node[:action]] }.to_json) }
  end

  def referenced_by?(parent, child)
    references.linked?(parent, child)
  end

  private

  def add(kind, scope)
    records = if scope.respond_to?(:lock)
                scope.order(:id).limit(LIMIT + 1).then { |s| @lock ? s.lock : s }.to_a
              else
                Array(scope)
              end
    raise JrcCrm::OrderDeletionService::Conflict, 'Inventário excede 1.000 registros; revise o alcance.' if nodes.size + records.size > LIMIT

    records.each do |record|
      raise Pundit::NotAuthorizedError if record.respond_to?(:account_id) && record.account_id != @account.id
      if record.respond_to?(:business_unit_id) && !JrcCrm::OrganizationalVisibility.new(account: @account, user: @actor,
                                                                                        relation: record.class.where(id: record.id)).call.exists?
        raise Pundit::NotAuthorizedError
      end

      action, reason = policy.classify(kind, record)
      nodes[[record.class.table_name, record.id]] ||= { record: record, kind: kind, action: action, reason: reason }
    end
    records
  end

  def policy
    @policy ||= JrcCrm::OrderDeletionPolicy.new(order_ids: @orders.map(&:id))
  end

  def references
    @references ||= JrcCrm::OrderDeletionReferences.new(nodes: nodes, issues: issues)
  end

  def collect
    add('orders', @orders)
    ids = @orders.map(&:id)
    add('items', JrcCrm::OrderItem.where(sales_order_id: ids))
    contracts = add('contracts', JrcCrm::Contract.where(sales_order_id: ids))
    add('contract_items', JrcCrm::ContractItem.where(contract_id: contracts.map(&:id)))
    invoices = add('invoices', JrcCrm::Invoice.where('sales_order_id IN (?) OR contract_id IN (?)', ids, contracts.map(&:id)))
    add('payments', JrcCrm::Payment.where(invoice_id: invoices.map(&:id)))
    add('commissions', JrcCrm::SalesCommission.where(sales_order_id: ids))
    backoffice = add('backoffice', JrcCrm::BackofficeRequest.where(sales_order_id: ids))
    collect_activities(ids)
    collect_projects(backoffice)
    collect_proposals
    nodes.values.map { |node| node[:record] }.each { |record| collect_evidence(record) }
  end

  def collect_activities(ids)
    activities = JrcCrm::Activity.where(sales_order_id: ids)
    @orders.each { |r| activities = activities.or(JrcCrm::Activity.where("metadata ->> 'sales_order_id' = ?", r.id.to_s)) }
    add('activities', activities)
  end

  def collect_projects(backoffice)
    project_ids = backoffice.filter_map { |r| r.metadata['implementation_project_id'] }
    keys = @orders.map { |r| "crm-order-implementation-#{r.id}" }
    projects = add('projects', JrcProjects::Project.where(account_id: @account.id).where('id IN (?) OR idempotency_key IN (?)', project_ids, keys))
    projects.each do |project|
      collect_project_dependencies(project)
      linked_ids = backoffice.select { |r| r.metadata['implementation_project_id'].to_s == project.id.to_s }.map(&:sales_order_id)
      linked_ids += @orders.select { |r| project.idempotency_key == "crm-order-implementation-#{r.id}" }.map(&:id)
      @orders.select { |r| linked_ids.include?(r.id) }.each { |r| preserve(r, 'Projeto de implantação vinculado; revisão operacional necessária.') }
    end
  end

  def collect_project_dependencies(project)
    %i[tasks time_entries boards board_columns project_members phases milestones operation_links].each do |association|
      add("project_#{association}", project.public_send(association))
    end
    add('project_budget', [project.budget].compact)
  end

  def collect_proposals
    ids = @orders.filter_map(&:proposal_id)
    add('proposals', JrcCrm::Proposal.where(id: ids))
    add('proposal_items', JrcCrm::ProposalItem.where(proposal_id: ids))
    add('proposal_events', JrcCrm::ProposalEvent.where(proposal_id: ids))
  end

  def collect_evidence(record)
    add('audit', JrcCrm::AuditEvent.where(account_id: @account.id, resource_type: record.class.name, resource_id: record.id))
    requests = add('approvals', JrcApprovals::Request.where(account_id: @account.id, resource_type: record.class.name, resource_id: record.id))
    requests.each do |request|
      add('approval_decisions', request.decisions)
      add('approval_audit', JrcApprovals::AuditEvent.where(account_id: @account.id, request_id: request.id))
    end
    attachments = add('documents', ActiveStorage::Attachment.where(record_type: record.class.base_class.name, record_id: record.id))
    return unless attachments.any? && !record.is_a?(JrcCrm::Proposal)

    preserve(record, 'Arquivo documental vinculado exige revisão de retenção.')
  end

  def protect_financial_evidence
    nodes.values.select { |n| n[:kind] == 'invoices' && n[:record].contract_id }.each do |n|
      parent = nodes[['jrc_crm_contracts', n[:record].contract_id]]
      if parent && parent[:action] != 'delete'
        preserve(n[:record],
                 'Faturamento de contrato preservado; aguardar cancelamento contratual responsável.')
      end
    end
    references.protect!
    nodes.values.select { |n| n[:kind] == 'items' }.each do |n|
      parent = nodes[['jrc_crm_sales_orders', n[:record].sales_order_id]]
      preserve(n[:record], 'Composição financeira do pedido preservado.') if parent[:action] != 'delete'
    end
    nodes.values.select { |n| n[:kind] == 'contract_items' }.each do |n|
      parent = nodes[['jrc_crm_contracts', n[:record].contract_id]]
      preserve(n[:record], 'Condições da minuta/contrato preservado.') if parent[:action] != 'delete'
    end
  end

  def preserve(record, reason)
    node = nodes.fetch([record.class.table_name, record.id])
    node[:action] = 'preserve'
    node[:reason] = reason
  end

  def protect_approvals
    nodes.values.select { |n| n[:kind] == 'approvals' && n[:action] == 'cancel' }.each do |node|
      request = node[:record]
      resource = nodes.values.find { |n| n[:record].class.name == request.resource_type && n[:record].id == request.resource_id }
      preserve(request, 'Alçada vinculada a registro preservado; nenhuma decisão ou solicitação será alterada.') if resource[:action] != 'delete'
    end
  end

  def public_row(node)
    r = node[:record]
    { type: node[:kind], label: LABELS.fetch(node[:kind], 'Dependência do projeto'), id: r.id, reference: row_reference(r),
      status: r.try(:status) || r.try(:state), action: node[:action], reason: node[:reason],
      amount_cents: r.try(:total_cents) || r.try(:amount_cents), created_at: r.created_at,
      evidence: row_evidence(r) }
  end

  def row_reference(record)
    %i[order_number contract_number invoice_number request_number].filter_map { |field| record.try(field) }.first || "##{record.id}"
  end

  def row_evidence(record)
    evidence = record.attributes.slice(*EVIDENCE_FIELDS)
    evidence['approval_decision'] = record.metadata['approval_decision'] if record.is_a?(JrcCrm::BackofficeRequest)
    evidence.compact
  end
end
