// The host's tab is hidden (another tab in front, like a host switching to read something) when a guest joins:
// browsers slow down hidden tabs, so does the room still answer?
import { pageUrl, launch, Player } from './cdp.mjs';

const BASE = pageUrl();
const chrome = await launch();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
try {
  const alice = new Player(chrome.browser, 'alice');
  const bob = new Player(chrome.browser, 'bob');
  await alice.openTab(BASE); await alice.waitReady();
  await alice.cmd('open'); await alice.cmd('host', 'Alice');
  const a = await alice.until((s) => s.in_match && s.room, 'alice has a room', 90000);
  log('alice hosts room', a.room);
  const other = await chrome.browser.send('Target.createTarget', { url: 'about:blank', browserContextId: alice.contextId });
  await chrome.browser.send('Target.activateTarget', { targetId: other.targetId });
  log('alice\'s game tab is now behind another tab; visibility:', await alice.eval('document.visibilityState'));
  if (process.env.WAIT) { await new Promise((r) => setTimeout(r, Number(process.env.WAIT) * 1000)); log('hidden for', process.env.WAIT, 's'); }
  await bob.openTab(BASE + '#room=' + a.room); await bob.waitReady(); await bob.cmd('open');
  const b = await bob.until((s) => s.in_match && s.synced, 'bob synced while the host tab is hidden', 45000);
  log('bob is in:', JSON.stringify(b.seats.map((s) => s.name)));
  log('ALL GOOD');
} catch (e) {
  console.error('FAILED', e.message);
  process.exitCode = 1;
} finally {
  await chrome.close();
}
