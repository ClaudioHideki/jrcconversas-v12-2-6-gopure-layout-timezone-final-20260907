import { activityDateTimeInput } from '../activityDateTime';
describe('Account-local activity editing', () => {
  it('uses the account-local form value rather than the browser timezone', () => {
    expect(activityDateTimeInput({due_at: '2026-08-29T13:00:00Z', due_at_input: '2026-08-29T10:00'})).toBe('2026-08-29T10:00');
  });
  it('supports existing account-local display values without inventing dates', () => {
    expect(activityDateTimeInput({due_at_display: '29/08/2026 10:00'})).toBe('2026-08-29T10:00');
    expect(activityDateTimeInput({})).toBe('');
  });
});
