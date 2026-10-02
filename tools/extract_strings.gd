extends SceneTree
## Rebuilds locale/messages.pot from the game's texts and merges them into each language's
## .po file: translations are kept, new texts arrive empty, texts no longer used are dropped.
##   godot --headless --script res://tools/extract_strings.gd

const LOCALE_DIR := "res://locale"


func _init() -> void:
	var scanner := StringScanner.new()
	scanner.scan_all()
	var template := PoFile.new()
	template.entries = scanner.entries
	_write("%s/messages.pot" % LOCALE_DIR, template.to_text(true))
	print("%d texts found." % scanner.entries.size())
	for code in Localization.LANGUAGES:
		if code == Localization.SOURCE_LANGUAGE:
			continue
		var path := "%s/%s.po" % [LOCALE_DIR, code]
		var existing := PoFile.load_file(path)
		var merged := PoFile.new()
		merged.header = existing.header
		var added := 0
		for key in scanner.entries:
			var found := scanner.entries[key]
			var entry := PoFile.PoEntry.new()
			entry.id = found.id
			entry.context = found.context
			entry.plural = found.plural
			entry.translations = found.translations.duplicate()
			if existing.entries.has(key):
				var old := existing.entries[key]
				for index in mini(old.translations.size(), entry.translations.size()):
					entry.translations[index] = old.translations[index]
			else:
				added += 1
			merged.entries[key] = entry
		var dropped := 0
		for key in existing.entries:
			if not merged.entries.has(key):
				dropped += 1
		_write(path, merged.to_text())
		var empty := merged.entries.values().filter(func(e: PoFile.PoEntry) -> bool: return not e.is_translated()).size()
		print("%s: %d new, %d dropped, %d still to translate." % [code, added, dropped, empty])
	if not scanner.unrouted.is_empty():
		print("Formatted texts set on a Control without tr() (never translated):")
		for line in scanner.unrouted:
			print("  ", line)
	quit()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s" % path)
		return
	file.store_string(text)
