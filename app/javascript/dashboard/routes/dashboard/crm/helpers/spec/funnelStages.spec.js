import { projectFunnelStages } from '../funnelStages';

it('shows four qualified leads and all three sent documents without moving or double-valuing deals', () => {
  const stages = [
    {
      id: 1,
      key: 'qualification',
      pipeline_id: 1,
      name: 'Qualificação',
      deals_count: 0,
      value_cents: 0,
    },
    {
      id: 2,
      key: 'proposal_sent',
      pipeline_id: 1,
      name: 'Proposta Enviada',
      deals_count: 0,
      value_cents: 0,
    },
    {
      id: 3,
      key: 'negotiation',
      pipeline_id: 1,
      name: 'Negociação',
      deals_count: 1,
      value_cents: 20000,
    },
    {
      id: 4,
      is_won: true,
      pipeline_id: 1,
      name: 'Ganho',
      deals_count: 1,
      value_cents: 30000,
    },
    {
      id: 5,
      is_lost: true,
      pipeline_id: 1,
      name: 'Perdido',
      deals_count: 1,
      value_cents: 10000,
    },
  ];
  const original = structuredClone(stages);
  const records = {
    qualified_leads: Array.from({ length: 4 }, (_, id) => ({
      id,
      name: `Lead ${id}`,
    })),
    sent_proposals: ['sent', 'accepted', 'canceled'].map((status, id) => ({
      id,
      pipeline_id: 1,
      status,
      total_cents: 999999,
    })),
  };
  const result = projectFunnelStages(stages, records);
  expect(result.map(s => s.records_count)).toEqual([4, 3, 1, 1, 1]);
  expect(result[1].proposals.map(p => p.status)).toEqual([
    'sent',
    'accepted',
    'canceled',
  ]);
  expect(result.reduce((sum, s) => sum + s.value_cents, 0)).toBe(60000);
  expect(stages).toEqual(original);
});

it('assigns each proposal to its own pipeline and shows unlinked records once in a read-only auxiliary column', () => {
  const stages = [1, 2].map(id => ({
    id,
    key: 'proposal_sent',
    name: 'Proposta Enviada',
    pipeline_id: id,
    deals_count: 0,
  }));
  const result = projectFunnelStages(stages, {
    qualified_leads: [{ id: 9 }],
    sent_proposals: [
      { id: 1, pipeline_id: 1 },
      { id: 2, pipeline_id: 2 },
      { id: 3, pipeline_id: null },
      { id: 4, pipeline_id: 99 },
    ],
  });
  expect(result[0].proposals.map(p => p.id)).toEqual([1]);
  expect(result[1].proposals.map(p => p.id)).toEqual([2]);
  expect(result.filter(s => s.virtual).map(s => s.key)).toEqual([
    'qualification',
    'proposal_sent',
  ]);
  expect(result.flatMap(s => s.proposals).map(p => p.id)).toHaveLength(4);
  expect(result.flatMap(s => s.leads).map(l => l.id)).toEqual([9]);
});

it('does not reuse terminal stages or repeat global leads in multiple pipelines', () => {
  const result = projectFunnelStages(
    [
      { id: 1, name: 'Qualificação', is_terminal: true, pipeline_id: 1 },
      { id: 2, key: 'qualification', name: 'Qualificação', pipeline_id: 2 },
      { id: 3, key: 'qualification', name: 'Qualificação', pipeline_id: 3 },
    ],
    { qualified_leads: [{ id: 9 }], sent_proposals: [] }
  );
  expect(result.map(s => s.leads_count)).toEqual([0, 1, 0]);
});
