@tool
class_name Localization
extends RefCounted
## Which language the game speaks. Texts are English in the code and the data (the message id
## of `tr()`); `locale/<code>.po` holds the other languages and Godot's TranslationServer
## swaps them in, falling back to the English text where a translation is missing.

const SOURCE_LANGUAGE := "en"
## Language code → the language's own name (shown as is, never translated, so a player who
## ended up in a language they can't read can still find theirs).
const LANGUAGES: Dictionary[String, String] = {"en": "English", "fr": "Français"}

## The system's language, read once before the first change; tests pin it.
static var _system_locale := ""


## The language to speak: the player's choice (a code of LANGUAGES), else the system's if
## supported, else English. `language` "" means automatic.
static func resolve(language: String) -> String:
	if LANGUAGES.has(language):
		return language
	var code := system_locale().substr(0, 2).to_lower()  # "fr_FR", "fr-CA", "fr".
	return code if LANGUAGES.has(code) else SOURCE_LANGUAGE


## Puts `language` ("" = automatic) into effect, on everything shown from now on.
static func apply(language: String) -> void:
	TranslationServer.set_locale(resolve(language))


## What the system asked for at startup (or `--language` on the command line).
static func system_locale() -> String:
	if _system_locale.is_empty():
		_system_locale = TranslationServer.get_locale()
	return _system_locale


## For tests: pretend the system speaks `locale`.
static func set_system_locale(locale: String) -> void:
	_system_locale = locale
