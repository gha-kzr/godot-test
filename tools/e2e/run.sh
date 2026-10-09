#!/bin/sh
# End-to-end test of the real network: exports the web build, serves it on localhost, starts the relay server
# (server/) on this machine and plays a whole match between isolated Chrome profiles (a room code, a started match,
# turns, a connection that breaks and comes back, host swap, the AI taking over, a return to the same seat).
# Needs Google Chrome (macOS path in cdp.mjs) and Node 20+. Nothing leaves the machine: the page is served from
# http://127.0.0.1:8061 and the game is pointed at ws://127.0.0.1:8787.
#   tools/e2e/run.sh            # export, serve, run full.mjs
#   tools/e2e/run.sh basic      # just two players meeting
#   RELAY_URL=default tools/e2e/run.sh basic   # against the real server (the game's own address) instead of the local one
set -e
cd "$(dirname "$0")/../.."
tools/export_web.sh > /dev/null
(cd server && npm ci --silent)
(cd build/web && python3 -m http.server 8061 --bind 127.0.0.1 > /dev/null 2>&1 & echo $! > /tmp/e2e-server.pid)
(cd server && PORT=8787 node index.mjs > /tmp/e2e-relay.log 2>&1 & echo $! > /tmp/e2e-relay.pid)
sleep 1
trap 'kill $(cat /tmp/e2e-server.pid) $(cat /tmp/e2e-relay.pid) 2>/dev/null; rm -f /tmp/e2e-server.pid /tmp/e2e-relay.pid' EXIT
node tools/e2e/${1:-full}.mjs
