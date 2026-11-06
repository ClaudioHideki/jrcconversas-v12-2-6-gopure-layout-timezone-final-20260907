# Conservative disposal rules; a cancellation/refund requires its native workflow.
class JrcCrm::OrderDeletionPolicy
  REMOVABLE = {
    'items' => 'Item exclusivo do pedido excluído.',
    'contract_items' => 'Item de minuta removível.'
  }.freeze
  RETAINED = {
    'payments' => 'Pagamento possui data de efetivação; conciliação pendente não o torna rascunho. Estorno deve ser registrado separadamente.',
    'projects' => 'Projeto possui ciclo e permissões próprios; revisar/cancelar em Projetos antes de eliminar sua origem.',
    'proposals' => 'Proposta de origem/aceite e versões não são propriedade exclusiva do pedido.',
    'proposal_items' => 'Condições históricas da proposta de origem.',
    'proposal_events' => 'Histórico de envio/aceite e PDFs da proposta.',
    'audit' => 'Auditoria permanece com identificação do registro e comprovante da exclusão.',
    'approval_decisions' => 'Decisão imutável de alçada.',
    'approval_audit' => 'Trilha imutável da solicitação de alçada.',
    'documents' => 'Arquivo sem classificação de descarte: preservar para revisão documental.'
  }.freeze
  CLASSIFIED = %w[orders contracts invoices commissions backoffice activities approvals].freeze
  EXTERNAL_KEY = /\A(?:external(?:_|$)|provider(?:_|$)|fiscal(?:_|$)|nf[es]e?(?:_|$)|charge(?:_id|$)|boleto(?:_id|$)|transaction(?:_id|$)|provisioning_confirmed$|completed_at$)/

  def initialize(order_ids:)
    @order_ids = order_ids
  end

  def classify(kind, record)
    return ['delete', REMOVABLE.fetch(kind)] if REMOVABLE.key?(kind)
    return ['preserve', RETAINED.fetch(kind)] if RETAINED.key?(kind)
    return public_send(kind, record) if CLASSIFIED.include?(kind)

    ['preserve', 'Dependência do projeto preservado; revisão pelo módulo Projetos.']
  end

  def orders(record)
    if %w[invoiced shipped completed].include?(record.status) || external_evidence?(record.snapshot)
      ['preserve', 'Pedido com execução/faturamento/entrega ou referência externa: usar cancelamento responsável.']
    else
      ['delete', 'Pedido sem efetivação externa ou obrigação de retenção identificada.']
    end
  end

  def contracts(record)
    pure = record.draft? && record.signature_status == 'not_started' && record.signed_at.nil? && record.signature_external_id.blank?
    pure &&= !record.documents.attached? && !record.signed_document.attached? && !external_evidence?(record.lifecycle_metadata)
    if pure
      ['delete', 'Minuta não assinada, sem envio ao provedor ou documentos.']
    else
      ['preserve', 'Contrato enviado/assinado ou com evidência documental: exige revisão/distrato pelo fluxo contratual.']
    end
  end

  def invoices(record)
    if record.sales_order_id.present? && @order_ids.exclude?(record.sales_order_id)
      ['preserve', 'Faturamento compartilhado com outro pedido; origem financeira preservada.']
    elsif record.draft? && record.issued_on.nil? && !external_evidence?(record.snapshot)
      ['delete', 'Rascunho financeiro não emitido e sem cobrança externa identificada.']
    else
      ['preserve', 'Faturamento emitido/cancelado ou cobrança externa: manter comprovantes; cancelamento fiscal/financeiro é separado.']
    end
  end

  def commissions(record)
    if record.forecast? && record.paid_at.nil? && record.released_at.nil? && record.accrued_at.nil?
      ['delete', 'Previsão não liberada ou paga.']
    else
      ['preserve', 'Comissão liberada/paga/estornada: preservar cálculo e ajuste auditável.']
    end
  end

  def backoffice(record)
    pure = record.order_approval? || (record.fulfillment? && record.pending? && record.stage == 'request')
    pure &&= !record.documents.attached? && !external_evidence?(record.metadata) && record.metadata['implementation_project_id'].blank?
    if pure
      ['delete', 'Solicitação interna sem efetivação; decisões e auditoria são preservadas no comprovante.']
    else
      ['preserve', 'Execução/documentos operacionais ou cancelamento em curso: manter histórico e usar Backoffice responsável.']
    end
  end

  def activities(record)
    exclusive = record.sales_order_id.nil? || @order_ids.include?(record.sales_order_id)
    exclusive &&= record.metadata.to_h['sales_order_id'].blank? || @order_ids.map(&:to_s).include?(record.metadata['sales_order_id'].to_s)
    if record.scheduled? && record.completed_at.nil? && record.conversation_id.nil? && exclusive && record.metadata.to_h['relationship_assignment_id'].blank?
      ['delete', 'Atividade agendada específica do pedido, sem execução ou conversa.']
    else
      ['preserve', 'Atividade executada ou compartilhada com atendimento/relacionamento; preservar evidência.']
    end
  end

  def approvals(record)
    if %w[pending returned escalated].include?(record.state)
      ['cancel', 'Cancelar solicitação pendente sem apagar decisões ou trilha.']
    else
      ['preserve', 'Decisão/alçada e seu histórico devem permanecer auditáveis.']
    end
  end

  private

  def external_evidence?(data)
    case data
    when Array then data.any? { |value| external_evidence?(value) }
    when Hash then data.any? { |key, value| value.present? && (key.to_s.match?(EXTERNAL_KEY) || external_evidence?(value)) }
    else false
    end
  end
end
