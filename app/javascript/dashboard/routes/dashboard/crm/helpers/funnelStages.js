// Leads and documents are read-only cards. They do not create opportunities,
// change their stages, or contribute again to the commercial deal totals.
const roleMatches = (stage, role) => {
  if (stage.is_won || stage.is_lost || stage.is_terminal) return false;
  const keys = {
    qualification: ['qualification', 'qualified'],
    proposal_sent: ['proposal_sent'],
  };
  const names = {
    qualification: ['qualificação', 'qualification', 'qualificados'],
    proposal_sent: ['proposta enviada', 'proposal sent'],
  };
  return (
    keys[role].includes(stage.key) ||
    names[role].includes(stage.name?.trim().toLowerCase())
  );
};

export const projectFunnelStages = (
  stages,
  records = {},
  labels = { qualification: 'Qualificação', proposal_sent: 'Proposta Enviada' }
) => {
  const result = stages.map(stage => ({ ...stage, leads: [], proposals: [] }));
  const auxiliary = role => {
    const id = `records-${role}`;
    let stage = result.find(row => row.id === id);
    if (!stage) {
      stage = {
        id,
        key: role,
        name: labels[role],
        virtual: true,
        deals_count: 0,
        value_cents: 0,
        leads: [],
        proposals: [],
      };
      result.push(stage);
    }
    return stage;
  };
  const leads = records.qualified_leads || [];
  if (leads.length) {
    // Unconverted leads have no pipeline: show them once, clearly identified.
    const stage = result.find(row => roleMatches(row, 'qualification'));
    (stage || auxiliary('qualification')).leads = leads;
  }
  (records.sent_proposals || []).forEach(proposal => {
    const stage = result.find(
      row =>
        roleMatches(row, 'proposal_sent') &&
        !row.virtual &&
        Number(row.pipeline_id) === Number(proposal.pipeline_id)
    );
    (stage || auxiliary('proposal_sent')).proposals.push(proposal);
  });
  return result.map(stage => ({
    ...stage,
    leads_count: stage.leads.length,
    proposals_count: stage.proposals.length,
    records_count:
      Number(stage.deals_count || 0) +
      stage.leads.length +
      stage.proposals.length,
  }));
};
