class JrcCrm::ProposalRevisionService
  RESET_ATTRIBUTES = {
    proposal_number: nil, status: 'draft', approval_status: 'not_required', commercial_approval_status: 'not_required',
    financial_approval_status: 'not_required', technical_approval_status: 'not_required', public_token_digest: nil,
    public_token_expires_at: nil, public_token_revoked_at: nil, sent_at: nil, viewed_at: nil, last_viewed_at: nil,
    viewed_count: 0, accepted_at: nil, rejected_at: nil, canceled_at: nil, accepted_by_name: nil, accepted_by_document: nil,
    accepted_from_ip: nil, accepted_user_agent: nil, locked_at: nil, last_sent_channel: nil,
    last_sent_message_id: nil, last_sent_conversation_id: nil
  }.freeze

  def initialize(proposal:, actor:)
    @proposal = proposal
    @actor = actor
  end

  def call
    history = JrcCrm::ProposalVersionHistory.new(@proposal)
    history.root.with_lock do
      @proposal.reload
      number = @proposal.account.jrc_crm_proposals.where(id: history.ids).maximum(:version_number).to_i + 1
      preserve_source_document
      revised = copy_document(number)
      record_lineage(revised)
      revised.reload
    end
  end

  private

  def preserve_source_document
    archive = JrcCrm::ProposalDocumentArchive.new(@proposal, actor: @actor)
    if @proposal.sent_at.present? && archive.blob.nil?
      @proposal.events.create!(account_id: @proposal.account_id, user: @actor, event_type: 'document_unavailable',
                               description: 'PDF original indisponível; nova versão criada sem reconstruir o documento antigo')
    else
      archive.capture!
    end
  end

  def copy_document(number)
    revised = @proposal.dup
    revised.assign_attributes(RESET_ATTRIBUTES.merge(version_number: number, owner_id: @actor.id,
                                                     title: "#{@proposal.title} - Versão #{number}", down_payment_cents: 0))
    revised.save!
    @proposal.proposal_items.find_each do |item|
      revised.proposal_items.create!(item.attributes.except('id', 'proposal_id', 'created_at', 'updated_at'))
    end
    revised.update!(down_payment_cents: @proposal.down_payment_cents)
    revised.recalculate_totals!
    revised
  end

  def record_lineage(revised)
    revised.events.create!(account_id: @proposal.account_id, user: @actor, event_type: 'duplicated',
                           metadata: { relationship_origin: @proposal.relationship_origin, source_proposal_id: @proposal.id },
                           description: "Nova versão criada a partir da proposta #{@proposal.proposal_number}")
    @proposal.events.create!(account_id: @proposal.account_id, user: @actor, event_type: 'version_created',
                             description: "Criada a versão #{revised.version_number}", metadata: { new_proposal_id: revised.id })
  end
end
