require 'rails_helper'

RSpec.describe JrcCrm::ProposalPipelineService do
  let(:account) { create(:account) }
  let(:actor) { create(:user, account: account) }
  let(:pipeline) { JrcCrm::DefaultPipelineService.new(account).perform }
  let(:entry) { pipeline.stages.find_by!(key: 'qualification') }
  let(:target) { pipeline.stages.find_by!(key: 'proposal_sent') }
  let(:deal) { create(:jrc_crm_deal, account: account, pipeline: pipeline, stage: entry, owner: actor) }
  let(:proposal) { create(:jrc_crm_proposal, account: account, owner: actor, deal: deal) }
  let(:service) { described_class.new(proposal: proposal, actor: actor) }

  it 'recognizes the imported stage name without rewriting its legacy key' do
    target.update!(key: 'sales-42')
    expect(service.call).to include(outcome: 'advanced', to_stage_id: target.id)
    expect(deal.reload.stage_id).to eq(target.id)
    expect(target.reload.key).to eq('sales-42')
  end

  it 'does not regress a negotiation' do
    negotiation = pipeline.stages.find_by!(key: 'negotiation')
    negotiation.update!(position: 1)
    deal.update!(stage: negotiation)
    expect { service.call }.not_to(change { deal.reload.stage_id })
  end

  %w[won lost archived].each do |status|
    it "does not reopen or alter a #{status} deal" do
      if status == 'archived'
        deal.update!(status: status)
      else
        stage = pipeline.stages.find_by!(key: status)
        deal.lost_reason = create(:jrc_crm_lost_reason, account: account, name: 'QA loss') if status == 'lost'
        deal.update!(stage: stage)
      end
      before = deal.reload.attributes.slice('status', 'stage_id', 'won_at', 'lost_at')
      expect(service.call).to be_nil
      expect(deal.reload.attributes.slice(*before.keys)).to eq(before)
    end
  end

  it 'does not select an inactive stage or one from a different pipeline' do
    target.update!(active: false)
    other = create(:jrc_crm_pipeline, account: account)
    create(:jrc_crm_stage, account: account, pipeline: other, key: 'proposal_sent', name: 'Proposta Enviada')
    expect(service.call).to include(outcome: 'not_configured')
    expect(deal.reload.stage_id).to eq(entry.id)
  end

  it 'warns instead of choosing between ambiguous imported stages' do
    target.update!(key: 'legacy-a')
    create(:jrc_crm_stage, account: account, pipeline: pipeline, key: 'legacy-b', name: 'Proposta Enviada', position: 20)
    expect(service.call).to include(outcome: 'not_configured', deal_id: deal.id)
    expect(deal.reload.stage_id).to eq(entry.id)
  end

  it 'keeps direct proposals without a deal outside the deal pipeline' do
    proposal.update!(deal: nil, contact: create(:contact, account: account))
    expect(service.call).to be_nil
  end

  it 'does not broaden an agent permission when a proposal and its deal have different owners' do
    member = account.account_users.find_by!(user_id: actor.id)
    member.update!(role: :agent)
    deal.update!(owner: create(:user, account: account))
    expect(service.call).to include(outcome: 'not_authorized')
    expect(deal.reload.stage_id).to eq(entry.id)
  end

  it 'does not move a deal for an actor from another account' do
    foreign_actor = create(:user, account: create(:account))
    result = described_class.new(proposal: proposal, actor: foreign_actor).call
    expect(result).to include(outcome: 'not_authorized')
    expect(deal.reload.stage_id).to eq(entry.id)
  end
end
