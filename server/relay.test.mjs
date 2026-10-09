import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { WebSocket } from "ws";
import { startRelay, normalizeCode } from "./relay.mjs";

let relay;
const sockets = [];

before(async () => {
  relay = await startRelay({ port: 0, maxMissesPerMinute: 4, burst: 20, perSecond: 5 });
});
after(async () => {
  for (const socket of sockets) socket.terminate();
  await relay.close();
});

/** A client: connects, collects what the server says, and lets a test wait for the next message that matches. */
async function client(options = {}) {
  const socket = new WebSocket(`ws://127.0.0.1:${relay.port}`, options);
  sockets.push(socket);
  const inbox = [];
  const waiting = [];
  socket.on("message", (data) => {
    const message = JSON.parse(data.toString());
    const index = waiting.findIndex((w) => w.match(message));
    if (index >= 0) waiting.splice(index, 1)[0].resolve(message);
    else inbox.push(message);
  });
  await new Promise((resolve, reject) => {
    socket.once("open", resolve);
    socket.once("error", reject);
  });
  return {
    socket,
    send: (message) => socket.send(JSON.stringify(message)),
    next: (match = () => true) =>
      new Promise((resolve, reject) => {
        const found = inbox.findIndex(match);
        if (found >= 0) return resolve(inbox.splice(found, 1)[0]);
        const entry = { match, resolve };
        waiting.push(entry);
        setTimeout(() => {
          const at = waiting.indexOf(entry);
          if (at >= 0) {
            waiting.splice(at, 1);
            reject(new Error("timed out waiting for a message"));
          }
        }, 1500);
      }),
    pending: () => inbox.length,
    closed: () => new Promise((resolve) => (socket.readyState === WebSocket.CLOSED ? resolve() : socket.once("close", resolve))),
  };
}

const ofType = (type) => (message) => message.t === type;

async function room() {
  const host = await client();
  host.send({ t: "host", token: "host-token-1234" });
  const welcome = await host.next(ofType("welcome"));
  return { host, code: welcome.room, welcome };
}

test("the player who opens a room is 1, with a code of six characters", async () => {
  const { welcome } = await room();
  assert.equal(welcome.id, 1);
  assert.deepEqual(welcome.peers, []);
  assert.equal(welcome.room.length, 6);
  assert.equal(normalizeCode(welcome.room), welcome.room);
});

test("a player joins with the code and everybody learns of it", async () => {
  const { host, code } = await room();
  const bob = await client();
  bob.send({ t: "join", room: code.toUpperCase(), token: "bob-token-12345" });
  const welcome = await bob.next(ofType("welcome"));
  assert.equal(welcome.id, 2);
  assert.deepEqual(welcome.peers, [1]);
  assert.deepEqual(await host.next(ofType("peer")), { t: "peer", id: 2 });
  const carol = await client();
  carol.send({ t: "join", room: code, token: "carol-token-123" });
  assert.deepEqual((await carol.next(ofType("welcome"))).peers, [1, 2]);
  assert.equal((await bob.next(ofType("peer"))).id, 3);
});

test("a message goes to one player or to all the others, and carries the sender's number", async () => {
  const { host, code } = await room();
  const bob = await client();
  bob.send({ t: "join", room: code, token: "bob-token-12345" });
  await bob.next(ofType("welcome"));
  const carol = await client();
  carol.send({ t: "join", room: code, token: "carol-token-123" });
  await carol.next(ofType("welcome"));
  bob.send({ t: "msg", to: 3, b: { m: "hi" } });
  assert.deepEqual(await carol.next(ofType("msg")), { t: "msg", from: 2, b: { m: "hi" } });
  bob.send({ t: "msg", b: { m: "all" } });
  assert.equal((await host.next((m) => m.t === "msg")).from, 2);
  assert.equal((await carol.next((m) => m.t === "msg")).b.m, "all");
  // A player cannot speak for another one: a `from` in the message is not used.
  bob.send({ t: "msg", to: 1, from: 3, b: { m: "forged" } });
  assert.equal((await host.next((m) => m.t === "msg" && m.b.m === "forged")).from, 2);
});

test("a message to nobody, to oneself or without a body goes nowhere", async () => {
  const { host, code } = await room();
  const bob = await client();
  bob.send({ t: "join", room: code, token: "bob-token-12345" });
  await bob.next(ofType("welcome"));
  bob.send({ t: "msg", to: 2, b: { m: "self" } });
  bob.send({ t: "msg", to: 42, b: { m: "nobody" } });
  bob.send({ t: "msg", to: 1, b: "text" });
  bob.send({ t: "msg", to: 1, b: { m: "real" } });
  assert.equal((await host.next(ofType("msg"))).b.m, "real");
  assert.equal(bob.pending(), 0);
});

test("a wrong code, a bad code and a bad token are refused", async () => {
  const bob = await client();
  bob.send({ t: "join", room: "zzzzzz", token: "bob-token-12345" });
  assert.equal((await bob.next(ofType("error"))).why, "no_room");
  bob.send({ t: "join", room: "nope", token: "bob-token-12345" });
  assert.equal((await bob.next(ofType("error"))).why, "bad_request");
  bob.send({ t: "join", room: "abcdef", token: "x" });
  assert.equal((await bob.next(ofType("error"))).why, "bad_request");
});

test("guessing codes is slowed down", async () => {
  const guesser = await client({ headers: { "x-forwarded-for": "9.9.9.9" } });
  for (let i = 0; i < 4; i++) {
    guesser.send({ t: "join", room: "zzzzz" + "abcd"[i], token: "guess-token-1234" });
    assert.equal((await guesser.next(ofType("error"))).why, "no_room");
  }
  guesser.send({ t: "join", room: "zzzzzz", token: "guess-token-1234" });
  assert.equal((await guesser.next(ofType("error"))).why, "slow_down");
});

test("a player who comes back with their token gets their own number, and the others see them go and return", async () => {
  const { host, code } = await room();
  const bob = await client();
  bob.send({ t: "join", room: code, token: "bob-token-12345" });
  await bob.next(ofType("welcome"));
  await host.next(ofType("peer"));
  bob.socket.close();
  assert.deepEqual(await host.next(ofType("left")), { t: "left", id: 2 });
  const back = await client();
  back.send({ t: "join", room: code, token: "bob-token-12345" });
  assert.equal((await back.next(ofType("welcome"))).id, 2);
  assert.deepEqual(await host.next(ofType("peer")), { t: "peer", id: 2 });
  const stranger = await client();
  stranger.send({ t: "join", room: code, token: "other-token-9876" });
  assert.equal((await stranger.next(ofType("welcome"))).id, 3, "numbers are not given twice");
});

test("a token already in use is refused, unless it is the same player coming back on a new connection", async () => {
  const { host, code } = await room();
  const twin = await client();
  twin.send({ t: "join", room: code, token: "host-token-1234" });
  assert.equal((await twin.next(ofType("error"))).why, "token_in_use");
  twin.send({ t: "join", room: code, token: "twin-token-12345" });
  assert.equal((await twin.next(ofType("welcome"))).id, 2, "a fresh token makes a new player");
  const back = await client();
  back.send({ t: "join", room: code, token: "host-token-1234", resume: true });
  const welcome = await back.next(ofType("welcome"));
  assert.equal(welcome.id, 1, "the old connection of the host is replaced");
  await host.closed();
  assert.deepEqual(welcome.peers, [2]);
});

test("a room that is full refuses more players, and an empty room disappears", async () => {
  const small = await startRelay({ port: 0, maxMembers: 2 });
  const open = async () => {
    const socket = new WebSocket(`ws://127.0.0.1:${small.port}`);
    sockets.push(socket);
    const messages = [];
    socket.on("message", (data) => messages.push(JSON.parse(data.toString())));
    await new Promise((resolve) => socket.once("open", resolve));
    const next = async (type) => {
      for (let i = 0; i < 100; i++) {
        const at = messages.findIndex((m) => m.t === type);
        if (at >= 0) return messages.splice(at, 1)[0];
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
      throw new Error("no " + type);
    };
    return { socket, next, send: (m) => socket.send(JSON.stringify(m)) };
  };
  const a = await open();
  a.send({ t: "host", token: "token-a-1234567" });
  const code = (await a.next("welcome")).room;
  const b = await open();
  b.send({ t: "join", room: code, token: "token-b-1234567" });
  await b.next("welcome");
  const c = await open();
  c.send({ t: "join", room: code, token: "token-c-1234567" });
  assert.equal((await c.next("error")).why, "room_full");
  assert.equal(small.rooms.size, 1);
  a.socket.close();
  b.socket.close();
  for (let i = 0; i < 100 && small.rooms.size > 0; i++) await new Promise((resolve) => setTimeout(resolve, 10));
  assert.equal(small.rooms.size, 0);
  await small.close();
});

test("a connection that floods the server is dropped", async () => {
  const { code } = await room();
  const bob = await client();
  bob.send({ t: "join", room: code, token: "bob-token-12345" });
  await bob.next(ofType("welcome"));
  for (let i = 0; i < 60; i++) bob.send({ t: "msg", b: { n: i } });
  await bob.closed();
});

test("a page from another site is refused", async () => {
  await assert.rejects(client({ headers: { origin: "https://evil.example" } }));
  await client({ headers: { origin: "https://gha-kzr.github.io" } });
});

test("the health check answers (it wakes a sleeping server) and allows any page to ask", async () => {
  const response = await fetch(`http://127.0.0.1:${relay.port}/health`);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("access-control-allow-origin"), "*");
});

test("codes are read the way they are typed", () => {
  assert.equal(normalizeCode("ABC-def"), "abcdef");
  assert.equal(normalizeCode("abc def"), "abcdef");
  assert.equal(normalizeCode("abc0ef"), "", "no look-alike characters");
  assert.equal(normalizeCode("abcde"), "");
  assert.equal(normalizeCode(12), "");
});
