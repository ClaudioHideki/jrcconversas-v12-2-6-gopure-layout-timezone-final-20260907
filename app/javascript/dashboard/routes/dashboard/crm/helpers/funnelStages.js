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

const commercialRole = stage => {
  if (stage.is_won) return 'won';
  if (stage.is_lost) return 'lost';
  if (roleMatches(stage, 'qualification')) return 'qualification';
  if (roleMatches(stage, 'proposal_sent')) return 'proposal_sent';
  const names = [stage.key, stage.name].map(value =>
    value?.trim().toLowerCase()
  );
  if (names.some(value => ['negotiation', 'negociação'].includes(value)))
    return 'negotiation';
  if (names.some(value => ['lead', 'new_lead', 'novo lead'].includes(value)))
    return 'new_lead';
  if (names.some(value => ['opportunity', 'oportunidade'].includes(value)))
    return 'opportunity';
  return `custom-${stage.id}`;
};

// This is a display projection, never a reclassification of stored deal stages.
// Group equivalent columns across pipelines while retaining real drop targets.
export const projectCommercialBoard = (stages, records, labels) => {
  const projected = projectFunnelStages(stages, records, labels);
  const groups = new Map();
  const open = { deals: [], count: 0, value: 0 };
  projected.forEach(stage => {
    const role = commercialRole(stage);
    const deals = (stage.deals || []).map(deal => ({
      ...deal,
      pipeline_name: stage.pipeline_name,
      source_stage_name: stage.name,
      source_probability: stage.probability,
    }));
    const openDeals = deals.filter(deal => deal.status === 'open');
    const count = stage.deals
      ? openDeals.length
      : Number(stage.open_deals_count || 0);
    const value = stage.deals
      ? openDeals.reduce((sum, deal) => sum + Number(deal.value_cents || 0), 0)
      : Number(stage.open_value_cents || 0);
    open.deals.push(...openDeals);
    open.count += count;
    open.value += value;
    if (!groups.has(role)) {
      groups.set(role, {
        ...stage,
        role,
        source_stages: [],
        deals: [],
        leads: [],
        proposals: [],
        deals_count: 0,
        value_cents: 0,
      });
    }
    const group = groups.get(role);
    if (!stage.virtual) group.source_stages.push(stage);
    group.deals.push(...deals.filter(deal => deal.status !== 'open'));
    group.deals_count += Number(stage.deals_count || 0) - count;
    group.value_cents += Number(stage.value_cents || 0) - value;
    group.leads.push(...stage.leads);
    group.proposals.push(
      ...stage.proposals.map(proposal => ({
        ...proposal,
        pipeline_name: stage.pipeline_name,
      }))
    );
  });
  if (open.count && !groups.has('negotiation')) {
    groups.set('negotiation', {
      id: 'open-negotiation',
      role: 'negotiation',
      name: labels.negotiation,
      virtual: true,
      source_stages: [],
      deals: [],
      leads: [],
      proposals: [],
      deals_count: 0,
      value_cents: 0,
    });
  }
  const negotiation = groups.get('negotiation');
  if (negotiation) {
    negotiation.deals.push(...open.deals);
    negotiation.deals_count += open.count;
    negotiation.value_cents += open.value;
  }
  const order = {
    new_lead: 0,
    qualification: 1,
    opportunity: 2,
    negotiation: 3,
    proposal_sent: 4,
    won: 5,
    lost: 6,
  };
  return [...groups.values()]
    .map(stage => ({
      ...stage,
      pipeline_name:
        stage.source_stages.length === 1 ? stage.pipeline_name : '',
      virtual: !stage.source_stages.length,
      leads_count: stage.leads.length,
      proposals_count: stage.proposals.length,
      records_count:
        stage.deals_count + stage.leads.length + stage.proposals.length,
    }))
    .filter(
      stage =>
        !['new_lead', 'opportunity'].includes(stage.role) || stage.records_count
    )
    .sort((a, b) => (order[a.role] ?? 2.5) - (order[b.role] ?? 2.5));
};

export const resolveBoardTarget = (column, deal, stages) => {
  const source = stages.find(
    stage => String(stage.id) === String(deal.stage_id)
  );
  const pipeline = deal.pipeline_id ?? source?.pipeline_id;
  return column.source_stages.find(
    stage => String(stage.pipeline_id) === String(pipeline)
  );
};
