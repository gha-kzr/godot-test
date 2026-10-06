class_name Emotes
extends RefCounted
## The quick messages a player can send: a fixed list, so the only thing on the wire is a number
## (nothing a player types ever reaches the others' screens through it).

const TEXTS: Array[String] = [
	"Hello!", "Good luck!", "Nice one!", "Ouch!", "Oops!", "Thanks!", "Wait for me", "Good game!",
]


static func count() -> int:
	return TEXTS.size()


## The text in the player's language (literals here so the translation tool finds them).
static func text(emote_id: int) -> String:
	match emote_id:
		0: return TranslationServer.translate("Hello!")
		1: return TranslationServer.translate("Good luck!")
		2: return TranslationServer.translate("Nice one!")
		3: return TranslationServer.translate("Ouch!")
		4: return TranslationServer.translate("Oops!")
		5: return TranslationServer.translate("Thanks!")
		6: return TranslationServer.translate("Wait for me")
		7: return TranslationServer.translate("Good game!")
	return ""
