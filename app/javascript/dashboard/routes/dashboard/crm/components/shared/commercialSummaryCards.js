export const commercialSummaryCards = (summary, t, formatBRL) => {
  const leadCount = Object.values(summary.leads || {}).reduce(
    (a, b) => a + Number(b),
    0
  );
  return [
    {
      key: 'LEADS',
      titleKey: 'REGISTERED_LEADS',
      helpKey: 'REGISTERED_LEADS_HELP',
      value: leadCount,
      details: [
        'new',
        'in_contact',
        'qualified',
        'converted',
        'unqualified',
        'lost',
      ]
        .filter(s => summary.leads?.[s])
        .map(s => [
          t(`CRM.COMMERCIAL_SUMMARY.LEAD_${s.toUpperCase()}`),
          summary.leads[s],
        ]),
    },
    {
      key: 'DEALS',
      value: formatBRL(summary.deals?.open?.value_cents || 0),
      details: ['open', 'won', 'lost'].map(s => [
        t(`CRM.COMMERCIAL_SUMMARY.DEAL_${s.toUpperCase()}`),
        formatBRL(summary.deals?.[s]?.value_cents || 0),
      ]),
    },
    {
      key: 'SENT',
      helpKey: 'SENT_DOCUMENTS_HELP',
      value: summary.proposals_sent_count || 0,
      details: [],
    },
    {
      key: 'ORDERS',
      value: summary.orders?.active_count || 0,
      details: [
        [
          t('CRM.COMMERCIAL_SUMMARY.PENDING'),
          summary.orders?.pending_count || 0,
        ],
      ],
    },
    {
      key: 'REVENUE',
      value: formatBRL(summary.orders?.revenue_cents || 0),
      details: [],
    },
    {
      key: 'SIGNED',
      value: formatBRL(summary.signed_proposals?.value_cents || 0),
      details: [
        [
          t('CRM.COMMERCIAL_SUMMARY.DOCUMENTS'),
          summary.signed_proposals?.count || 0,
        ],
      ],
    },
  ];
};
