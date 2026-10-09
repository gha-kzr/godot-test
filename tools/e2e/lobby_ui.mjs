// The lobby with real mouse clicks on the real controls: joining a team by clicking its card, and every change of the
// map or the rules leaving the players Ready as they were (the host's and the guest's).
import { mkdirSync } from 'node:fs';
import { pageUrl, launch, Player, sleep } from './cdp.mjs';

const OUT = 'build/e2e-shots';
mkdirSync(OUT, { recursive: true });
const chrome = await launch();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const check = (cond, m) => { if (!cond) throw new Error('CHECK FAILED: ' + m); log('ok:', m); };
try {
  const alice = new Player(chrome.browser, 'alice');
  const bob = new Player(chrome.browser, 'bob');
  for (const p of [alice, bob]) { await p.openTab(pageUrl()); await p.waitReady(); await p.cmd('open'); }
  await alice.cmd('host', 'Alice');
  const room = (await alice.until((s) => s.in_match && s.room, 'a room', 90000)).room;
  await bob.cmd('join', 'Bob', room);
  await bob.until((s) => s.synced, 'bob synced', 40000);
  await sleep(800);
  // The teams: a real click on each card.
  for (const p of [alice, bob]) await p.wheel(400, 400, 900);
  await sleep(500);
  await alice.clickOn('TeamA');
  await sleep(500);
  log('bob sees TeamB at', JSON.stringify(await bob.where('TeamB')), 'and the viewport is', await bob.eval('innerWidth + "x" + innerHeight'));
  await bob.shot(`${OUT}/lobby-ui-bob-before.png`);
  await bob.clickOn('TeamB');
  await alice.until((s) => s.seats.find((x) => x.id === 1).side === 0 && s.seats.find((x) => x.id === 2).side === 1, 'both joined a team by a click');
  check(true, 'a click on a team card joins it');
  const readyBoth = async () => {
    for (const p of [alice, bob]) {
      const seatId = (await p.status()).my_id;
      if (!(await p.status()).seats.find((x) => x.id === seatId).ready) await p.clickOn('Ready');
    }
    await alice.until((s) => s.seats.every((x) => x.ready), 'everyone ready', 8000);
  };
  const stillReady = async (what) => {
    await sleep(600);
    for (const p of [alice, bob]) {
      const s = await p.status();
      check(s.seats.every((x) => x.ready), `${what}: everybody is still ready on ${p.name}'s state`);
    }
  };
  const scrollToRules = async () => { for (const p of [alice, bob]) await p.wheel(1100, 300, 900); await sleep(400); };
  // Size: a click on the spin box's up arrow.
  await readyBoth(); await scrollToRules();
  await alice.clickOn('Size', 0.96, 0.25);
  await stillReady('size');
  await alice.shot(`${OUT}/lobby-ui-after-size.png`);
  // Map shape: open the list, go down one, accept.
  await readyBoth(); await scrollToRules();
  const shapeBefore = (await alice.status()).settings.typology;
  await alice.clickOn('Typology'); await sleep(400);
  await alice.shot(`${OUT}/lobby-ui-shape-list.png`);
  const list = await alice.where('Typology');
  await alice.click(list[0] + list[2] * 0.3, list[1] + list[3] / 2 + 56);  // the second entry of the list that opened
  await sleep(600);
  const shapeAfter = (await alice.status()).settings.typology;
  log('map shape', shapeBefore, '->', shapeAfter);
  check(shapeAfter !== shapeBefore, 'the map shape really changed (otherwise this test did not reach the list)');
  await stillReady('map shape');
  await alice.shot(`${OUT}/lobby-ui-after-shape.png`);
  // New map.
  await readyBoth(); await scrollToRules();
  await alice.clickOn('NewSeed');
  await stillReady('new map');
  log('ALL GOOD');
} catch (e) {
  console.error('FAILED', e.message);
  process.exitCode = 1;
} finally {
  await chrome.close();
}
