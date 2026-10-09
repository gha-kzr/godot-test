import { pageUrl, launch, Player, sleep } from './cdp.mjs';

const BASE = pageUrl();
const chrome = await launch();
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const fail = (m) => { throw new Error(m); };
const check = (cond, m) => { if (!cond) fail('CHECK FAILED: ' + m); log('ok:', m); };

async function connect(room, newcomer, name) {
  await newcomer.cmd('join', name, room);
  await newcomer.until((s) => s.synced, `${name} synced`, 40000);
}

async function inStep(players, what, timeoutMs = 15000) {
  const start = Date.now();
  let last;
  while (Date.now() - start < timeoutMs) {
    last = await Promise.all(players.map((p) => p.status()));
    if (last.every((s) => s.entries === last[0].entries && s.fingerprint === last[0].fingerprint)) return last[0];
    await sleep(300);
  }
  fail(`not in step (${what}): ` + JSON.stringify(last.map((s) => [s.entries, s.fingerprint])));
}

// Plays `count` end-of-turns, by whoever's turn it is (waits while the AI plays).
async function playTurns(players, count) {
  let done = 0;
  const start = Date.now();
  while (done < count && Date.now() - start < 90000) {
    const statuses = await Promise.all(players.map((p) => p.status()));
    if (statuses[0].over) return done;
    const mine = statuses.findIndex((s) => s.my_turn);
    if (mine >= 0) { await players[mine].cmd('end_turn'); done++; await sleep(400); } else await sleep(400);
  }
  return done;
}

try {
  const alice = new Player(chrome.browser, 'alice');
  const bob = new Player(chrome.browser, 'bob');
  const carol = new Player(chrome.browser, 'carol');
  for (const p of [alice, bob, carol]) await p.openTab(BASE);
  await Promise.all([alice, bob, carol].map((p) => p.waitReady()));
  for (const p of [alice, bob, carol]) await p.cmd('open');
  await alice.cmd('host', 'Alice');
  const room = (await alice.until((s) => s.in_match && s.room, 'alice has a room', 90000)).room;
  log('alice hosts room', room);
  await connect(room, bob, 'Bob');
  await connect(room, carol, 'Carol');
  await alice.until((s) => s.peers.length === 2, 'alice reaches both');
  check(true, 'three players in one room');
  await inStep([alice, bob, carol], 'lobby');

  // Lobby: sides, map, timers, ready, start.
  await alice.cmd('set', 'side', 0);
  await bob.cmd('set', 'side', 1); await carol.cmd('set', 'side', 1);
  await bob.cmd('set', 'hero', 1); await carol.cmd('set', 'hero', 2);
  await alice.cmd('cfg', 'grace', 6); await alice.cmd('cfg', 'turn', 20);
  await alice.cmd('cfg', 'typology', 'ruins'); await alice.cmd('cfg', 'seed', 77);
  for (const p of [alice, bob, carol]) await p.cmd('ready', true);
  await sleep(1000);
  await alice.cmd('start');
  for (const p of [alice, bob, carol]) await p.until((s) => s.phase === 1, 'battle phase');
  check(true, 'the match started on all three');
  for (const p of [alice, bob, carol]) await p.cmd('placed');
  for (const p of [alice, bob, carol]) await p.until((s) => s.started, 'fight started');
  const s0 = await inStep([alice, bob, carol], 'after placement');
  log('the fight began, entries', s0.entries, 'screens', JSON.stringify((await Promise.all([alice, bob, carol].map((p) => p.status()))).map((s) => s.screen)));

  // Turns.
  const played = await playTurns([alice, bob, carol], 6);
  check(played >= 6, `six turns played (${played})`);
  const s1 = await inStep([alice, bob, carol], 'after six turns');
  check(s1.entries > s0.entries, 'the log grew');

  // Bob's connection to the server breaks: it comes back by itself, to the same seat, and the match goes on.
  await bob.cmd('blink');
  await bob.until((s) => s.synced && s.peers.length === 2 && !s.connection, 'bob reconnected', 30000);
  await alice.until((s) => s.seats.find((x) => x.id === 2).connected && s.peers.length === 2, 'alice sees bob back', 30000);
  check((await bob.status()).my_id === 2 && (await bob.status()).host_id === 1, 'bob is back in seat 2 and alice is still the host');
  await inStep([alice, bob, carol], 'after the blink');

  // Host swap: Alice's tab closes.
  await alice.closeTab();
  log('alice closed her tab');
  const b = await bob.until((s) => s.host_id === 2 && !s.peers.includes(1), 'bob is the new host', 30000);
  const c = await carol.until((s) => s.host_id === 2 && !s.peers.includes(1), 'carol follows bob', 30000);
  check(true, `host swap: bob is host (bob sees ${b.host_id}, carol sees ${c.host_id})`);
  // After the grace period the AI plays Alice's hero; the game goes on.
  await bob.until((s) => s.seats.find((x) => x.id === 1).ai, 'AI replaces alice', 40000);
  check(true, 'the AI took over alice\'s hero');
  const before = (await bob.status()).entries;
  const played2 = await playTurns([bob, carol], 4);
  check(played2 >= 3, `bob and carol keep playing (${played2} turns)`);
  const s2 = await inStep([bob, carol], 'after the swap');
  check(s2.entries > before, 'the log keeps growing under the new host');

  // Alice comes back: she opens the room link in the browser she left (it kept her token).
  await alice.openTab(BASE + '#room=' + room);
  await alice.waitReady();
  await alice.cmd('open');  // The page's address holds the room code: it joins by itself.
  const a2 = await alice.until((s) => s.synced, 'alice synced again', 40000);
  check(a2.my_id === 1 && a2.phase === 1, 'alice is back in seat 1, in the fight');
  await alice.until((s) => !s.seats.find((x) => x.id === 1).ai, 'alice gets her hero back', 60000);
  check(true, 'the AI gave the hero back');
  const s3 = await inStep([alice, bob, carol], 'after the return');
  check(true, `all three agree again at entry ${s3.entries}`);
  const played3 = await playTurns([alice, bob, carol], 4);
  check(played3 >= 3, `three players play again (${played3} turns)`);
  await inStep([alice, bob, carol], 'end');
  log('ALL GOOD');
} catch (e) {
  console.error('FAILED', e.message);
  console.error('console:', chrome.browser.logs.slice(-12));
  process.exitCode = 1;
} finally {
  await chrome.close();
}
