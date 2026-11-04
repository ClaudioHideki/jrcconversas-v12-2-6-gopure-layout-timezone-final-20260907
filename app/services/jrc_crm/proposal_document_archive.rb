require 'stringio'

class JrcCrm::ProposalDocumentArchive
  def initialize(proposal, actor: nil)
    @proposal = proposal
    @actor = actor
  end

  def blob
    event = @proposal.events.where(event_type: %w[document_archived sent]).order(id: :desc)
                     .with_attached_document.find { |entry| entry.document.attached? }
    return event.document.blob if event

    message = @proposal.account.messages.find_by(id: @proposal.last_sent_message_id)
    return unless message && message.content_attributes.to_h['jrc_crm_proposal_id'] == @proposal.id

    original_pdf(message)
  end

  def capture!
    @proposal.with_lock do
      existing = blob
      # Never replace a previously sent PDF with a reconstruction of today's data.
      raise ArgumentError, 'O PDF original não está disponível. Crie uma nova versão da proposta.' if @proposal.sent_at.present? && !existing

      existing ||= ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(JrcCrm::ProposalPdfService.new(@proposal).call),
        filename: "#{@proposal.proposal_number.parameterize}-v#{@proposal.version_number}.pdf", content_type: 'application/pdf'
      )
      unless @proposal.events.exists?(event_type: 'document_archived')
        event = @proposal.events.create!(account_id: @proposal.account_id, user: @actor, event_type: 'document_archived',
                                         description: 'Documento original preservado para consulta histórica',
                                         metadata: { total_cents: @proposal.total_cents, version_number: @proposal.version_number })
        event.document.attach(existing)
      end
      existing
    end
  end

  private

  def original_pdf(message)
    attachment = message.attachments.find { |entry| entry.file.attached? && entry.file.content_type == 'application/pdf' }
    attachment&.file&.blob
  end
end
