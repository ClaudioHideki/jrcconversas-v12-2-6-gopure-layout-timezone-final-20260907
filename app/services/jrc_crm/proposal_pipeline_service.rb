# A delivery advances an open deal only once. Resends and historical documents
# must not undo a salesperson's later decision or reopen a terminal deal.
class JrcCrm::ProposalPipelineService
  def initialize(proposal:, actor:)
    @proposal = proposal
    @actor = actor
  end

  def call
    deal = @proposal.deal
    return unless deal

    deal.with_lock do
      next unless eligible?(deal)

      unless authorized_deal?(deal)
        next { outcome: 'not_authorized', deal_id: deal.id,
               warning: 'O envio foi registrado, mas a alteração da etapa exige permissão sobre o negócio.' }
      end

      target = proposal_stage(deal)
      unless target
        next { outcome: 'not_configured', deal_id: deal.id,
               warning: 'O envio foi registrado, mas o funil não possui uma etapa Proposta Enviada identificável; revise a etapa do negócio.' }
      end
      next unless deal.stage.position < target.position

      advance(deal, target)
    end
  end

  private

  def eligible?(deal)
    deal.open? && !deal.stage.is_terminal? && deal.stage.key != 'negotiation' &&
      %w[negociação negotiation].exclude?(deal.stage.name.strip.downcase)
  end

  def authorized_deal?(deal)
    account = @proposal.account
    membership = account.account_users.find_by(user_id: @actor.id)
    return false unless membership

    context = { user: @actor, account: account, account_user: membership }
    return false unless JrcCrm::DealPolicy.new(context, deal).move_stage?

    JrcCrm::OrganizationalVisibility.new(account: account, user: @actor, relation: account.jrc_crm_deals.where(id: deal.id)).call.exists?
  end

  def advance(deal, target)
    from_stage_id = deal.stage_id
    result = JrcCrm::DealPipelineService.new(deal: deal, stage: target, actor: @actor).call
    if result[:success]
      { outcome: 'advanced', deal_id: deal.id, from_stage_id: from_stage_id, to_stage_id: target.id }
    else
      { outcome: 'failed', deal_id: deal.id, warning: "O envio foi registrado, mas a etapa do negócio precisa de revisão: #{result[:error]}" }
    end
  end

  def proposal_stage(deal)
    stages = deal.pipeline.stages.active.where(is_terminal: false, is_won: false, is_lost: false)
    canonical = stages.find_by(key: 'proposal_sent')
    return canonical if canonical

    named = stages.where('LOWER(BTRIM(name)) IN (?)', ['proposta enviada', 'proposal sent']).limit(2).to_a
    named.first if named.one?
  end
end
