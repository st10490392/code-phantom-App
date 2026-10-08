const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');
const script = fs.readFileSync('scripts/firebase-messaging-sw.template.js', 'utf8').replace('__FIREBASE_WEB_CONFIG__', '{}');
const data = { event_id: '12345678-1234-1234-1234-123456789012', signal_id: '87654321-4321-4321-4321-210987654321', type: 'TP' };
async function click(payload, windows = []) {
  let listener, pending;
  const opened = [];
  vm.runInNewContext(script, { URL, importScripts() {}, firebase: { initializeApp() {}, messaging() {} }, self: {
    location: { origin: 'https://signals.example' }, addEventListener(_, fn) { listener = fn; },
    clients: { async matchAll() { return windows; }, async openWindow(url) { opened.push(url); } },
  } });
  listener({ notification: { data: payload, close() {} }, stopImmediatePropagation() {}, waitUntil(value) { pending = value; } });
  await pending;
  return opened;
}
test('cold web tap only opens same-origin entitled signal route', async () => {
  assert.deepEqual(await click({ FCM_MSG: { data: { ...data, url: 'https://evil.example', strategy: 'private' } } }), ['https://signals.example/signals/' + data.signal_id]);
});
test('malformed or unsupported payload never redirects', async () => {
  for (const value of [null, {}, { ...data, signal_id: '../admin' }, { ...data, type: 'private' }]) assert.deepEqual(await click(value), []);
});
test('existing same-origin window is navigated and focused', async () => {
  const actions = [];
  const windows = [{ url: 'https://evil.example', navigate() { throw Error('cross origin'); } }, { url: 'https://signals.example/dashboard', async navigate(url) { actions.push(url); }, async focus() { actions.push('focus'); } }];
  assert.deepEqual(await click(data, windows), []);
  assert.deepEqual(actions, ['https://signals.example/signals/' + data.signal_id, 'focus']);
});
