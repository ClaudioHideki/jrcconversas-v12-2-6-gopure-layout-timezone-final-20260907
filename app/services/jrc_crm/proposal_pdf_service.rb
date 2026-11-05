module JrcCrm
  class ProposalPdfService
    def initialize(record)
      @record = record
    end

    def call
      original = ProposalDocumentArchive.new(@record).blob
      return original.download if original

      CommercialDocumentService.new(kind: :proposal, record: @record).call
    end
  end
end
