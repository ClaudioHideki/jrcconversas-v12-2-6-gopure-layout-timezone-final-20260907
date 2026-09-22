// Pure production helper, not a mounted Vue/browser or HTTP test.
import test from 'node:test';
import assert from 'node:assert/strict';
import { activityDateTimeInput } from '../../../app/javascript/dashboard/routes/dashboard/crm/activityDateTime.js';
for (const zone of ['UTC', 'America/Sao_Paulo', 'Asia/Tokyo']) {
  test(`account-local activity stays 10:00 with browser timezone ${zone}`, () => {
    const previous = process.env.TZ;
    try {
      process.env.TZ = zone;
      assert.equal(activityDateTimeInput({ due_at: '2026-08-29T13:00:00Z', due_at_input: '2026-08-29T10:00' }), '2026-08-29T10:00');
    } finally {
      if (previous === undefined) delete process.env.TZ;
      else process.env.TZ = previous;
    }
  });
}
test('older API account-local display is accepted without browser conversion', () => {
  assert.equal(activityDateTimeInput({due_at: '2026-08-29T13:00:00Z', due_at_display: '29/08/2026 10:00'}), '2026-08-29T10:00');
});
test('missing or invalid local fields stay blank, not an invented instant', () => {
  assert.equal(activityDateTimeInput(null), '');
  assert.equal(activityDateTimeInput({due_at: '2026-08-29T13:00:00Z'}), '');
  assert.equal(activityDateTimeInput({due_at_input: 'bad', due_at_display: 'bad'}), '');
});
test('new local field takes precedence over legacy display', () => {
  assert.equal(activityDateTimeInput({due_at_input: '2026-08-30T09:00',due_at_display: '29/08/2026 10:00'}), '2026-08-30T09:00');
});
