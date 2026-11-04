class JrcCrm::ProposalVersionHistory
  def initialize(proposal)
    @proposal = proposal
    @scope = proposal.account.jrc_crm_proposals
  end

  def root
    current = @proposal
    visited = []
    loop do
      raise ArgumentError, 'Invalid proposal version lineage' if visited.include?(current.id)

      visited << current.id
      source_id = current.events.where(event_type: 'duplicated').order(:id).pick(:metadata)&.dig('source_proposal_id')
      return current unless source_id

      current = @scope.find(source_id)
    end
  end

  def ids
    found = [root.id]
    frontier = found
    until frontier.empty?
      children = JrcCrm::ProposalEvent.where(account_id: @proposal.account_id, event_type: 'duplicated')
                                      .where("metadata ->> 'source_proposal_id' IN (?)", frontier.map(&:to_s)).pluck(:proposal_id)
      frontier = @scope.where(id: children - found).pluck(:id)
      found += frontier
    end
    found
  end
end
