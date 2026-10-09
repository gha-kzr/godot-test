// A guest opens the room link (#room=code) and joins by itself: the way friends are invited.
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
  if (process.env.WAIT) { await new Promise((r) => setTimeout(r, Number(process.env.WAIT) * 1000)); log('waited', process.env.WAIT, 's'); }
  await bob.openTab(BASE + '#room=' + a.room);
  await bob.waitReady();
  await bob.cmd('open');  // Past the click-to-start screen: an address with a room code joins from here.
  const b = await bob.until((s) => s.in_match && s.synced, 'bob synced through the room link', 60000);
  log('bob is in:', JSON.stringify(b.seats.map((s) => s.name)));
  log('ALL GOOD');
} catch (e) {
  console.error('FAILED', e.message);
  console.error('console:', chrome.browser.logs.slice(-10));
  process.exitCode = 1;
} finally {
  await chrome.close();
}
