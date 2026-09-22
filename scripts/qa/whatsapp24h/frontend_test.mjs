// Run: node --test scripts/qa/whatsapp24h/frontend_test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildJrcTemplateParameters, templateValidationErrors, variableKeys,
  renderTemplatePart, windowState, friendlyWhatsappError } from '../../../app/javascript/dashboard/helper/whatsappTemplateFlow.mjs';
const basic = { components: [{ type: 'BODY', text: 'Ola {{1}} - {{2}}' }] };
const snapshot = { has_service_window: true, window_status: 'OPEN', can_send_free_message: true,
  server_time: '2026-09-21T19:00:00Z', expires_at: '2026-09-21T20:00:00Z' };
test('builds numeric body variables with explicit defaults', () => {
  assert.deepEqual(buildJrcTemplateParameters(basic, { 'body.1': 'Ana' }), { body: { '1': 'Ana', '2': '' } });
});
test('deduplicates and sorts numeric variables while preserving named order', () => {
  assert.deepEqual(variableKeys('{{10}} {{2}} {{1}} {{2}}'), ['1', '2', '10']);
  assert.deepEqual(variableKeys('{{ nome }} {{protocolo}}'), ['nome', 'protocolo']);
});
test('does not infer a numeric variable from contact name', () => {
  assert.equal(buildJrcTemplateParameters(basic).body['1'], '');
});
test('requires every body variable', () => {
  assert.equal(templateValidationErrors(basic, { body: { '1': 'Ana' } }).length, 1);
  assert.equal(templateValidationErrors(basic, { body: { '1': 'Ana', '2': '#22' } }).length, 0);
});
test('requires text header variables even with a static body', () => {
  const tpl = { components: [{ type: 'BODY', text: 'Ola' }, { type: 'HEADER', format: 'TEXT', text: 'Pedido {{1}}' }] };
  const params = buildJrcTemplateParameters(tpl);
  assert.equal(templateValidationErrors(tpl, params).length, 1);
  params.header['1'] = '#22';
  assert.equal(templateValidationErrors(tpl, params).length, 0);
});
test('a static body and static buttons need no parameter', () => {
  const tpl = { components: [{ type: 'BODY', text: 'Ola' }, { type: 'BUTTONS', buttons: [{ type: 'URL', text: 'Site', url: 'https://example.invalid' }, { type: 'QUICK_REPLY', text: 'Sim' }] }] };
  const params = buildJrcTemplateParameters(tpl);
  assert.equal(templateValidationErrors(tpl, params).length, 0);
  assert.equal(Object.hasOwn(params.buttons[0], 'parameter'), false);
});
test('dynamic URL and copy-code buttons require values and enforce coupon length', () => {
  const tpl = { components: [{ type: 'BODY', text: 'Ola' }, { type: 'BUTTONS', buttons: [{ type: 'URL', url: 'https://example.invalid/{{1}}' }, { type: 'COPY_CODE' }] }] };
  const params = buildJrcTemplateParameters(tpl);
  assert.equal(templateValidationErrors(tpl, params).length, 2);
  params.buttons[0].parameter = 'order-22'; params.buttons[1].parameter = 'TEST';
  assert.equal(templateValidationErrors(tpl, params).length, 0);
  params.buttons[1].parameter = 'a'.repeat(16);
  assert.equal(templateValidationErrors(tpl, params).length, 1);
});
test('media headers reject non-HTTP or credential-bearing URLs', () => {
  const tpl = { components: [{ type: 'BODY', text: 'Ola' }, { type: 'HEADER', format: 'IMAGE' }] };
  const params = buildJrcTemplateParameters(tpl);
  for (const url of ['', 'file:///etc/passwd', 'javascript:alert(1)', 'https://u:p@example.invalid/a']) {
    params.header.media_url = url; assert.equal(templateValidationErrors(tpl, params).length, 1);
  }
  params.header.media_url = 'https://example.invalid/image.png';
  assert.equal(templateValidationErrors(tpl, params).length, 0);
});
test('rejects newlines, blank values and overly long body fields', () => {
  for (const value of ['   ', 'a\nb', 'a\tb', 'a'.repeat(1001)]) {
    assert.equal(templateValidationErrors(basic, { body: { '1': value, '2': 'ok' } }).length, 1);
  }
});
test('preview retains apostrophes, quotes and comparison signs as text', () => {
  assert.equal(renderTemplatePart('Ola {{ nome }}', { nome: 'D\'Avila <teste> "x"' }), 'Ola D\'Avila <teste> "x"');
});
test('open snapshot countdown uses server time, not client wall clock', () => {
  assert.equal(windowState(snapshot).remaining_seconds, 3600);
  assert.equal(windowState(snapshot, 60000).remaining_seconds, 3540);
});
test('exact expiration disables free messages even without another request', () => {
  assert.equal(windowState(snapshot, 3600000).can_send_free_message, false);
  assert.equal(windowState(snapshot, 3600000).window_status, 'CLOSED');
});
test('closed, unknown and awaiting-reply snapshots never unlock', () => {
  for (const status of ['CLOSED', 'UNKNOWN', 'TEMPLATE_REQUIRED']) {
    assert.equal(windowState({ ...snapshot, window_status: status, awaiting_customer_reply: true }).can_send_free_message, false);
  }
  assert.equal(windowState(null).can_send_free_message, false);
});
test('invalid timestamps and elapsed time fail closed', () => {
  assert.equal(windowState({ ...snapshot, expires_at: 'invalid' }).can_send_free_message, false);
  assert.equal(windowState(snapshot, NaN).can_send_free_message, false);
  assert.equal(windowState(snapshot, Infinity).can_send_free_message, false);
});
test('a newer customer-reply snapshot enables a fresh window', () => {
  const closed = windowState(snapshot, 3600001);
  assert.equal(closed.can_send_free_message, false);
  assert.equal(windowState({ ...snapshot, server_time: '2026-09-22T19:00:00Z', expires_at: '2026-09-23T19:00:00Z' }).remaining_seconds, 86400);
});
test('known provider codes have operational messages instead of bare codes', () => {
  for (const code of ['131047', '132001', '132015', '132000', '131026', '131049']) {
    assert.equal(friendlyWhatsappError(code).includes(code), false);
    assert.ok(friendlyWhatsappError(code).length > 35);
  }
});
test('Vuex wrapper returns the actual send promise so modal errors are observable', async () => {
  const source = readFileSync(new URL('../../../app/javascript/dashboard/store/modules/conversations/actions.js', import.meta.url), 'utf8');
  const match = source.match(/createPendingMessageAndSend: async \(\{ dispatch \}, data\) => \{([\s\S]*?)\n  \},/);
  assert.ok(match);
  const wrapper = new Function('createPendingMessage', `return async ({dispatch}, data) => {${match[1]}}`)(data => data);
  let resolve; const pending = new Promise(r => { resolve = r; }); let done = false;
  const request = wrapper({ dispatch: () => pending }, {}).then(() => { done = true; });
  await Promise.resolve(); assert.equal(done, false); resolve(); await request; assert.equal(done, true);
  await assert.rejects(wrapper({ dispatch: () => Promise.reject(new Error('blocked')) }, {}), /blocked/);
});
