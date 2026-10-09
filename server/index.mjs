// Starts the relay (Render runs `npm start`; it gives the port in PORT).
import { startRelay } from "./relay.mjs";

const origins = process.env.ALLOWED_ORIGINS?.split(",").map((text) => text.trim()).filter(Boolean);
const relay = await startRelay({
  port: Number(process.env.PORT ?? 8787),
  ...(origins?.length ? { allowedOrigins: origins } : {}),
  log: (entry) => console.log(JSON.stringify(entry)),
});
console.log(JSON.stringify({ event: "listening", port: relay.port }));

// Render stops a service with SIGTERM: tell the players (their game reconnects) instead of cutting them off.
process.on("SIGTERM", async () => {
  await relay.close();
  process.exit(0);
});
