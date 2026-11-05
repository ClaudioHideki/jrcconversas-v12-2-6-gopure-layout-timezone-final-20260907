import { calculateOrderMetrics } from '../orderMetrics';

describe('commercial order metrics', () => {
  it('counts pending orders separately, preserving their financial values', () => {
    const rows = [
      { status: 'pending', total_cents: 90000, monthly_cents: 1000 },
      { status: 'draft', total_cents: 80000 },
      {
        status: 'approved',
        commercial_status: 'active',
        commercial_flow: 'simple',
        total_cents: 12000,
      },
      { status: 'completed', total_cents: 8000 },
      { status: 'canceled', total_cents: 70000 },
    ];
    const before = structuredClone(rows);
    expect(calculateOrderMetrics(rows)).toMatchObject({
      count: 5,
      total: 20000,
      active: 2,
      approval: 2,
      ticket: 10000,
      conversion: 40,
      mrr: 0,
    });
    expect(rows).toEqual(before);
  });
  it('uses the same approval rule for historical comparison, removal and empty filters', () => {
    expect(
      calculateOrderMetrics([{ status: 'pending', total_cents: 99000 }]).total
    ).toBe(0);
    expect(
      calculateOrderMetrics([
        { status: 'approved', total_cents: 99000, snapshot: { removal: {} } },
      ]).count
    ).toBe(0);
    expect(calculateOrderMetrics([])).toMatchObject({
      total: 0,
      ticket: 0,
      conversion: 0,
      active: 0,
    });
  });
});
