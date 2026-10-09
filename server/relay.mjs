// The relay: rooms of players who send each other messages through this server.
//
// The server knows nothing about the game. A room has a code, its members have numbers (seat ids: the player who
// opens the room is 1, then 2, 3...), and a message goes from one member to one other member, or to all of them.
// The server puts the sender's number on every message itself, so nobody can speak for someone else.
//
// A member's number is tied to a hash of the player's secret token: the same token gets the same number back
// (a player who reloads the page or loses the connection comes back to their own seat). Rooms live in memory
// only and disappear with their last member.
//
// Client -> server (JSON text):
//   {t:"host", token}              open a new room (the opener is 1)
//   {t:"join", room, token, resume?}  enter a room; `resume` is a reconnect of a player already in it (it replaces
//                                     the dead connection instead of being refused)
//   {t:"msg", to?, b}              b (an object) to member `to`, or to everyone else when `to` is absent
// Server -> client:
//   {t:"welcome", room, id, peers}  you are in, as `id`; `peers` are the members already there
//   {t:"peer", id} / {t:"left", id}  someone entered / left
//   {t:"msg", from, b}
//   {t:"error", why}                no_room, room_full, token_in_use, bad_request, server_full, slow_down

import { createServer } from "node:http";
import { randomInt } from "node:crypto";
import { WebSocketServer } from "ws";

const ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";
export const CODE_LENGTH = 6;

const DEFAULTS = {
  port: 8787,
  maxRooms: 300,
  maxMembers: 12,
  maxId: 999,
  maxConnectionsPerIp: 30,
  /** Joins that found no room, per address, in the last minute, before it is told to slow down. */
  maxMissesPerMinute: 10,
  maxPayload: 2 * 1024 * 1024,
  /** Messages per second a connection may send (a burst, then a steady rate). */
  burst: 300,
  perSecond: 150,
  pingEvery: 25_000,
  allowedOrigins: [
    "https://gha-kzr.github.io",
    "http://localhost:*",
    "http://127.0.0.1:*",
  ],
  log: () => {},
};

function originAllowed(origin, patterns) {
  if (!origin) return true; // Not a browser (a script, a test).
  return patterns.some((pattern) =>
    pattern.endsWith("*") ? origin.startsWith(pattern.slice(0, -1)) : origin === pattern,
  );
}

function makeCode(taken) {
  for (;;) {
    let code = "";
    for (let i = 0; i < CODE_LENGTH; i++) code += ALPHABET[randomInt(ALPHABET.length)];
    if (!taken.has(code)) return code;
  }
}

export function normalizeCode(text) {
  if (typeof text !== "string") return "";
  const code = text.toLowerCase().replace(/[\s_-]/g, "");
  if (code.length !== CODE_LENGTH) return "";
  for (const ch of code) if (!ALPHABET.includes(ch)) return "";
  return code;
}

export function startRelay(options = {}) {
  const config = { ...DEFAULTS, ...options };
  /** @type {Map<string, {code: string, members: Map<number, any>, tokens: Map<string, number>, nextId: number}>} */
  const rooms = new Map();
  const connectionsByIp = new Map();
  const missesByIp = new Map();

  const http = createServer((request, response) => {
    const headers = { "access-control-allow-origin": "*", "cache-control": "no-store" };
    if (request.url === "/health" || request.url === "/") {
      response.writeHead(200, { ...headers, "content-type": "text/plain" });
      response.end("ok");
    } else {
      response.writeHead(404, headers);
      response.end();
    }
  });
  const wss = new WebSocketServer({
    server: http,
    maxPayload: config.maxPayload,
    verifyClient: ({ origin }) => originAllowed(origin, config.allowedOrigins),
  });

  const send = (socket, message) => {
    if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(message));
  };

  const clientIp = (request) => {
    const forwarded = request.headers["x-forwarded-for"];
    if (typeof forwarded === "string" && forwarded) return forwarded.split(",").pop().trim(); // The proxy's own entry.
    return request.socket.remoteAddress ?? "?";
  };

  const tooManyMisses = (ip) => {
    const now = Date.now();
    const recent = (missesByIp.get(ip) ?? []).filter((time) => now - time < 60_000);
    missesByIp.set(ip, recent);
    return recent.length >= config.maxMissesPerMinute;
  };
  const noteMiss = (ip) => missesByIp.get(ip)?.push(Date.now());

  const validToken = (token) => typeof token === "string" && token.length >= 8 && token.length <= 128;

  function enter(connection, room, id) {
    const peers = [...room.members.keys()].sort((a, b) => a - b);
    for (const member of room.members.values()) send(member.socket, { t: "peer", id });
    room.members.set(id, connection);
    connection.room = room;
    connection.id = id;
    send(connection.socket, { t: "welcome", room: room.code, id, peers });
    config.log({ event: "enter", room: room.code, id, members: room.members.size });
  }

  function leave(connection) {
    const room = connection.room;
    if (!room || room.members.get(connection.id) !== connection) return;
    room.members.delete(connection.id);
    connection.room = null;
    for (const member of room.members.values()) send(member.socket, { t: "left", id: connection.id });
    if (room.members.size === 0) {
      rooms.delete(room.code);
      config.log({ event: "closed", room: room.code, rooms: rooms.size });
    }
  }

  function onHost(connection, message) {
    if (!validToken(message.token)) return send(connection.socket, { t: "error", why: "bad_request" });
    if (rooms.size >= config.maxRooms) return send(connection.socket, { t: "error", why: "server_full" });
    const room = { code: makeCode(rooms), members: new Map(), tokens: new Map(), nextId: 2 };
    room.tokens.set(message.token, 1);
    rooms.set(room.code, room);
    config.log({ event: "opened", room: room.code, rooms: rooms.size });
    enter(connection, room, 1);
  }

  function onJoin(connection, message) {
    const code = normalizeCode(message.room);
    if (!code || !validToken(message.token)) return send(connection.socket, { t: "error", why: "bad_request" });
    if (tooManyMisses(connection.ip)) return send(connection.socket, { t: "error", why: "slow_down" });
    const room = rooms.get(code);
    if (!room) {
      noteMiss(connection.ip);
      return send(connection.socket, { t: "error", why: "no_room" });
    }
    let id = room.tokens.get(message.token);
    if (id !== undefined) {
      const holder = room.members.get(id);
      if (holder) {
        if (message.resume !== true) return send(connection.socket, { t: "error", why: "token_in_use" });
        holder.room = null; // The old connection is dead to the player: it goes without telling anyone.
        room.members.delete(id);
        holder.socket.close(4000, "replaced");
        for (const member of room.members.values()) send(member.socket, { t: "left", id });
      }
    } else {
      if (room.members.size >= config.maxMembers || room.nextId > config.maxId) {
        return send(connection.socket, { t: "error", why: "room_full" });
      }
      id = room.nextId++;
      room.tokens.set(message.token, id);
    }
    enter(connection, room, id);
  }

  function onMessage(connection, message) {
    const room = connection.room;
    if (!room || typeof message.b !== "object" || message.b === null) return;
    const packet = JSON.stringify({ t: "msg", from: connection.id, b: message.b });
    const deliver = (member) => {
      if (member.socket.readyState === member.socket.OPEN && member.socket.bufferedAmount < 8 * 1024 * 1024) {
        member.socket.send(packet);
      }
    };
    if (message.to === undefined) {
      for (const [id, member] of room.members) if (id !== connection.id) deliver(member);
    } else if (Number.isInteger(message.to) && message.to !== connection.id) {
      const target = room.members.get(message.to);
      if (target) deliver(target);
    }
  }

  wss.on("connection", (socket, request) => {
    const ip = clientIp(request);
    const count = (connectionsByIp.get(ip) ?? 0) + 1;
    if (count > config.maxConnectionsPerIp) return socket.close(1008, "too many connections");
    connectionsByIp.set(ip, count);
    const connection = { socket, ip, room: null, id: 0, tokens: config.burst, last: Date.now(), attempts: 0 };
    socket.isAlive = true;
    socket.on("pong", () => (socket.isAlive = true));
    socket.on("message", (data, isBinary) => {
      const now = Date.now();
      connection.tokens = Math.min(config.burst, connection.tokens + ((now - connection.last) / 1000) * config.perSecond);
      connection.last = now;
      if (isBinary || --connection.tokens < 0) return socket.close(1008, "too fast");
      let message;
      try {
        message = JSON.parse(data.toString());
      } catch {
        return;
      }
      if (typeof message !== "object" || message === null) return;
      if (message.t === "msg") return onMessage(connection, message);
      if (connection.room || ++connection.attempts > 8) {
        if (!connection.room) socket.close(1008, "too many tries");
        return; // Already in a room: another host / join is ignored.
      }
      if (message.t === "host") onHost(connection, message);
      else if (message.t === "join") onJoin(connection, message);
    });
    socket.on("close", () => {
      leave(connection);
      const left = (connectionsByIp.get(ip) ?? 1) - 1;
      if (left <= 0) connectionsByIp.delete(ip);
      else connectionsByIp.set(ip, left);
    });
    socket.on("error", () => {});
  });

  // Connections that stop answering are dropped (a player whose network vanished), which tells the room.
  const pinger = setInterval(() => {
    for (const socket of wss.clients) {
      if (socket.isAlive === false) {
        socket.terminate();
        continue;
      }
      socket.isAlive = false;
      socket.ping();
    }
  }, config.pingEvery);
  const cleaner = setInterval(() => {
    const now = Date.now();
    for (const [ip, times] of missesByIp) {
      const recent = times.filter((time) => now - time < 60_000);
      if (recent.length === 0) missesByIp.delete(ip);
      else missesByIp.set(ip, recent);
    }
  }, 60_000);
  pinger.unref();
  cleaner.unref();

  return new Promise((resolve) => {
    http.listen(config.port, () => {
      resolve({
        port: http.address().port,
        rooms,
        close: () =>
          new Promise((done) => {
            clearInterval(pinger);
            clearInterval(cleaner);
            for (const socket of wss.clients) socket.close(1012, "restart");
            wss.close(() => http.close(() => done()));
            http.closeAllConnections?.();
          }),
      });
    });
  });
}
