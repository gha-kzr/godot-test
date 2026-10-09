class_name RelayConfig
extends RefCounted
## Where the relay server is. The address below is the one the Render service in `render.yaml` gets
## (its name decides it): change it here if the service is named differently or lives somewhere else.
## For development, `?relay=ws://127.0.0.1:8787` in the page address (or the RELAY_URL environment variable on a
## desktop build) points the game at a server on this machine; any other address in the page is ignored, so a link
## can't send a player to somebody else's server.

const DEFAULT_URL := "wss://rune-ascent-relay.onrender.com"


static func url() -> String:
	var custom := WebPage.query("relay") if WebPage.is_web() else OS.get_environment("RELAY_URL")
	if custom.begins_with("ws://127.0.0.1") or custom.begins_with("ws://localhost"):
		return custom
	return DEFAULT_URL


## The server's health page: asking it wakes a sleeping server (about a minute) before anyone needs it.
static func health_url() -> String:
	return url().replace("wss://", "https://").replace("ws://", "http://") + "/health"
