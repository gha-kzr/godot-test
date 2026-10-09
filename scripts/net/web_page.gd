class_name WebPage
extends RefCounted
## What the browser page knows, when the game runs in one: its address (and the part after #, where a
## room link keeps its code), and the clipboard. Elsewhere these answer with harmless defaults.

const DEFAULT_URL := "https://gha-kzr.github.io/rune-ascent-multiplayer/"


static func is_web() -> bool:
	return OS.has_feature("web")


## The page's address, without a fragment.
static func url() -> String:
	if is_web():
		var href: Variant = JavaScriptBridge.eval("window.location.href.split('#')[0]", true)
		if href is String and not (href as String).is_empty():
			return href
	return DEFAULT_URL


## The text after the # of the page's address ("" outside a browser).
static func fragment() -> String:
	if is_web():
		var hash_text: Variant = JavaScriptBridge.eval("window.location.hash", true)
		if hash_text is String:
			return (hash_text as String).trim_prefix("#")
	return ""


## Removes the fragment from the address bar (so a reload doesn't try to join again).
static func clear_fragment() -> void:
	if is_web():
		JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.search)", true)


## A query parameter of the page's address ("" when absent or outside a browser).
static func query(key: String) -> String:
	if is_web():
		var value: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('%s') || ''" % key, true)
		if value is String:
			return value
	return ""


## Keeps the game running while its tab is hidden. A browser stops a hidden tab's animation frames, and the game's loop
## with them: a host who looks at another tab would stop answering the players who join, and a player would look gone.
## While the page is hidden the loop is driven by a timer instead (browsers run those about once a second, enough to
## answer a joiner and to stay connected); a visible page uses the browser's frames as usual.
static func keep_running_when_hidden() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("""
		(function () {
			if (window.__runWhenHidden) { return; }
			window.__runWhenHidden = true;
			var native = window.requestAnimationFrame.bind(window);
			var pending = null;
			window.requestAnimationFrame = function (callback) {
				var done = false;
				var run = function (time) {
					if (done) { return; }
					done = true;
					if (pending === run) { pending = null; }
					callback(time === undefined ? performance.now() : time);
				};
				pending = run;
				var id = native(run);
				if (document.hidden) { setTimeout(run, 200); }
				return id;
			};
			document.addEventListener('visibilitychange', function () {
				if (document.hidden && pending) { setTimeout(pending, 0); }
			});
		})();
	""", true)


static func copy(text: String) -> void:
	DisplayServer.clipboard_set(text)
