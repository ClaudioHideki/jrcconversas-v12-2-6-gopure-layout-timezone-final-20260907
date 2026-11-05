// Commercial approval is independent of billing, fulfillment and digital signature.
export const isCommerciallyActive = order =>
  !order.snapshot?.removal &&
  ['approved', 'separating', 'invoiced', 'shipped', 'completed'].includes(
    order.status
  );

export const calculateOrderMetrics = rows => {
  const visible = rows.filter(row => !row.snapshot?.removal);
  const approved = visible.filter(isCommerciallyActive);
  const total = approved.reduce(
    (sum, row) => sum + Number(row.total_cents || 0),
    0
  );
  return {
    count: visible.length,
    total,
    mrr: approved.reduce((sum, row) => sum + Number(row.monthly_cents || 0), 0),
    approval: visible.filter(row => ['draft', 'pending'].includes(row.status))
      .length,
    implementation: visible.filter(
      row =>
        (row.commercial_flow !== 'simple' && row.status === 'approved') ||
        ['separating', 'invoiced', 'shipped'].includes(row.status)
    ).length,
    active: approved.length,
    ticket: approved.length ? Math.round(total / approved.length) : 0,
    conversion: visible.length
      ? Math.round((approved.length / visible.length) * 100)
      : 0,
  };
};
