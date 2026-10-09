import { pageUrl, launch, Player, sleep } from './cdp.mjs';

const URL = pageUrl();
const chrome = await launch();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
try {
  const alice = new Player(chrome.browser, 'alice');
  const bob = new Player(chrome.browser, 'bob');
  await alice.openTab(URL); await bob.openTab(URL);
  await Promise.all([alice.waitReady(), bob.waitReady()]);
  log('both games are up');
  await alice.cmd('open'); await bob.cmd('open');
  await alice.cmd('host', 'Alice');
  const a0 = await alice.until((s) => s.in_match && s.room, 'alice has a room', 90000);
  log('alice hosts room', a0.room);
  log('bob joins:', await bob.cmd('join', 'Bob', a0.room));
  const a = await alice.until((s) => s.seats && s.seats.length === 2 && s.peers.length === 1, 'two seats on alice');
  const b = await bob.until((s) => s.synced && s.seats.length === 2, 'bob synced');
  log('alice sees', JSON.stringify(a.seats.map((s) => s.name)), 'bob sees', JSON.stringify(b.seats.map((s) => s.name)), 'host', b.host_id, 'screens', a.screen, b.screen);
  await sleep(1500);
  log('alice fingerprint', (await alice.status()).fingerprint, 'bob', (await bob.status()).fingerprint);
  log('ALL GOOD');
} catch (e) {
  console.error('FAILED', e.message);
  console.error('console:', chrome.browser.logs.slice(-15));
  process.exitCode = 1;
} finally {
  await chrome.close();
}
