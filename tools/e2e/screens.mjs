// Screenshots of the lobby (teams, settings) and the fight (a quick message above a hero, the settings over the fight)
// in build/e2e-shots/, to look at what the screens really draw.
import { mkdirSync } from 'node:fs';
import { pageUrl, launch, Player, sleep } from './cdp.mjs';

const OUT = 'build/e2e-shots';
mkdirSync(OUT, { recursive: true });
const chrome = await launch();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
try {
  const alice = new Player(chrome.browser, 'alice');
  const bob = new Player(chrome.browser, 'bob');
  for (const p of [alice, bob]) { await p.openTab(pageUrl()); await p.waitReady(); await p.cmd('open'); }
  await alice.cmd('host', 'Alice');
  const room = (await alice.until((s) => s.in_match && s.room, 'a room', 90000)).room;
  await bob.cmd('join', 'Bob', room);
  await bob.until((s) => s.synced, 'bob synced', 40000);
  await alice.cmd('set', 'side', 0);
  await sleep(1200);
  await alice.wheel(400, 400, 900);
  await sleep(600);
  await alice.shot(`${OUT}/1-lobby-bob-has-no-team.png`);
  await bob.cmd('set', 'side', 1);
  for (const p of [alice, bob]) await p.cmd('ready', true);
  await sleep(1200);
  await alice.cmd('cfg', 'size', 12);  // takes every Ready back
  await sleep(1200);
  await alice.wheel(400, 400, 900);
  await sleep(600);
  await alice.shot(`${OUT}/2-lobby-after-a-rule-change.png`);
  for (const p of [alice, bob]) await p.cmd('ready', true);
  await sleep(800);
  await alice.cmd('start');
  for (const p of [alice, bob]) await p.until((s) => s.phase === 1, 'battle');
  for (const p of [alice, bob]) await p.cmd('placed');
  for (const p of [alice, bob]) await p.until((s) => s.started, 'fight started');
  await sleep(2500);
  await alice.cmd('emote', 1);
  await sleep(1200);
  await alice.shot(`${OUT}/3-fight-message-above-the-hero.png`);
  await alice.cmd('ghost');
  await sleep(500);
  await alice.shot(`${OUT}/3a-fight-hero-in-stealth.png`);
  await alice.clickOn('SayButton');
  await sleep(500);
  await alice.shot(`${OUT}/3b-fight-say-popup.png`);
  await alice.clickOn('Emote0');
  await sleep(400);
  await alice.cmd('settings');
  await sleep(1000);
  await alice.shot(`${OUT}/4-settings-over-the-fight.png`);
  log('shots in', OUT);
} catch (e) {
  console.error('FAILED', e.message);
  process.exitCode = 1;
} finally {
  await chrome.close();
}
