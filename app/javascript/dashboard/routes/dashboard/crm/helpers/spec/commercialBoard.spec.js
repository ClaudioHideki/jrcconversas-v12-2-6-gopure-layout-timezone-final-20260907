import { projectCommercialBoard, resolveBoardTarget } from '../funnelStages';

const labels = {
  qualification: 'Qualificação',
  negotiation: 'Negociação',
  proposal_sent: 'Proposta Enviada',
};

it('collects all open deals once in Negotiation, after qualification and before sent proposals, preserving actual stages and weights', () => {
  const stages = [
    {
      id: 1,
      pipeline_id: 1,
      pipeline_name: 'GoPure',
      key: 'new_lead',
      name: 'Novo Lead',
      probability: 10,
      deals_count: 1,
      value_cents: 1000,
      deals: [
        {
          id: 10,
          pipeline_id: 1,
          stage_id: 1,
          status: 'open',
          value_cents: 1000,
        },
      ],
    },
    {
      id: 2,
      pipeline_id: 1,
      pipeline_name: 'GoPure',
      key: 'proposal_sent',
      name: 'Proposta Enviada',
      deals_count: 0,
      value_cents: 0,
      deals: [],
    },
    {
      id: 3,
      pipeline_id: 1,
      pipeline_name: 'GoPure',
      key: 'negotiation',
      name: 'Negociação',
      probability: 70,
      deals_count: 1,
      value_cents: 2000,
      deals: [
        {
          id: 11,
          pipeline_id: 1,
          stage_id: 3,
          status: 'open',
          value_cents: 2000,
        },
      ],
    },
    {
      id: 4,
      pipeline_id: 2,
      pipeline_name: 'Operadora',
      key: 'opportunity',
      name: 'Oportunidade',
      probability: 40,
      deals_count: 1,
      value_cents: 3000,
      deals: [
        {
          id: 12,
          pipeline_id: 2,
          stage_id: 4,
          status: 'open',
          value_cents: 3000,
        },
      ],
    },
    {
      id: 5,
      pipeline_id: 2,
      key: 'proposal_sent',
      name: 'Proposta Enviada',
      deals_count: 0,
      deals: [],
    },
    {
      id: 6,
      pipeline_id: 1,
      is_won: true,
      name: 'Ganho',
      deals_count: 1,
      value_cents: 9000,
      deals: [{ id: 13, stage_id: 6, status: 'won', value_cents: 9000 }],
    },
    {
      id: 7,
      pipeline_id: 1,
      is_lost: true,
      name: 'Perdido',
      deals_count: 1,
      value_cents: 500,
      deals: [{ id: 14, stage_id: 7, status: 'lost', value_cents: 500 }],
    },
  ];
  const original = structuredClone(stages);
  const records = {
    qualified_leads: [{ id: 31 }],
    sent_proposals: [
      { id: 41, pipeline_id: 1, status: 'accepted', total_cents: 9000 },
      { id: 42, pipeline_id: 2, status: 'sent' },
      { id: 43, pipeline_id: null, status: 'canceled' },
    ],
  };
  const columns = projectCommercialBoard(stages, records, labels);
  expect(columns.map(row => row.role)).toEqual([
    'qualification',
    'negotiation',
    'proposal_sent',
    'won',
    'lost',
  ]);
  expect(
    columns[1].deals.map(deal => [
      deal.id,
      deal.stage_id,
      deal.source_probability,
    ])
  ).toEqual([
    [10, 1, 10],
    [11, 3, 70],
    [12, 4, 40],
  ]);
  expect(columns[1]).toMatchObject({ deals_count: 3, value_cents: 6000 });
  expect(columns[2].proposals.map(row => row.id)).toEqual([41, 42, 43]);
  expect(columns.flatMap(column => column.deals).map(deal => deal.id)).toEqual([
    10, 11, 12, 13, 14,
  ]);
  expect(columns.reduce((sum, row) => sum + row.value_cents, 0)).toBe(15500);
  expect(stages).toEqual(original);
});

it('uses the same open-stage aggregates for dashboard and report projections without adding proposal money', () => {
  const columns = projectCommercialBoard(
    [
      {
        id: 1,
        pipeline_id: 1,
        key: 'new_lead',
        name: 'Novo Lead',
        deals_count: 2,
        value_cents: 6000,
        open_deals_count: 2,
        open_value_cents: 6000,
      },
      {
        id: 2,
        pipeline_id: 1,
        key: 'negotiation',
        name: 'Negociação',
        deals_count: 1,
        value_cents: 1000,
        open_deals_count: 1,
        open_value_cents: 1000,
      },
      {
        id: 3,
        pipeline_id: 2,
        key: 'lead',
        name: 'Lead',
        deals_count: 1,
        value_cents: 800,
        open_deals_count: 1,
        open_value_cents: 800,
      },
      {
        id: 4,
        pipeline_id: 1,
        is_won: true,
        name: 'Ganho',
        deals_count: 1,
        value_cents: 9000,
        open_deals_count: 0,
        open_value_cents: 0,
      },
    ],
    {
      qualified_leads: [],
      sent_proposals: [{ id: 10, pipeline_id: 1, total_cents: 999999 }],
    },
    labels
  );
  expect(columns.map(row => row.role)).toEqual([
    'negotiation',
    'proposal_sent',
    'won',
  ]);
  expect(columns[0]).toMatchObject({ deals_count: 4, value_cents: 7800 });
  expect(columns.reduce((sum, row) => sum + row.deals_count, 0)).toBe(5);
  expect(columns.reduce((sum, row) => sum + row.value_cents, 0)).toBe(16800);
});

it('resolves a grouped drop to the real stage of the same pipeline, never to a different pipeline', () => {
  const stages = [
    { id: 1, pipeline_id: 1, name: 'Negociação', key: 'negotiation' },
    { id: 2, pipeline_id: 2, name: 'Negociação', key: 'negotiation' },
    { id: 3, pipeline_id: 1, name: 'Ganho', is_won: true },
    { id: 4, pipeline_id: 2, name: 'Ganho', is_won: true },
  ];
  const columns = projectCommercialBoard(stages, {}, labels);
  const won = columns.find(column => column.role === 'won');
  expect(
    resolveBoardTarget(won, { pipeline_id: 2, stage_id: 2 }, stages).id
  ).toBe(4);
  expect(
    resolveBoardTarget(won, { pipeline_id: 1, stage_id: 1 }, stages).id
  ).toBe(3);
  expect(
    resolveBoardTarget(won, { pipeline_id: 99, stage_id: 9 }, stages)
  ).toBeUndefined();
});
