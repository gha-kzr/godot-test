class_name RoomCode
extends RefCounted
## The short code that names a room on the relay server (the server makes it): 6 characters from an alphabet
## without look-alikes, written in two groups of three. Anyone who knows it can join the lobby, so it is shared
## like a password; the server slows down anyone who guesses.

const ALPHABET := "abcdefghjkmnpqrstuvwxyz23456789"
const LENGTH := 6
const LINK_KEY := "room"


## The code as typed or pasted: lower case, without spaces, dashes or a link around it. "" when it isn't one.
static func normalize(text: String) -> String:
	var trimmed := text.strip_edges()
	var marker := "%s=" % LINK_KEY
	var at := trimmed.find(marker)
	if at != -1 and (at == 0 or trimmed[at - 1] in ["#", "&", "?"]):
		trimmed = trimmed.substr(at + marker.length())
		var end := trimmed.find("&")
		if end != -1:
			trimmed = trimmed.left(end)
	var clean := ""
	for character in trimmed.to_lower():
		if character in [" ", "-", "_"]:
			continue
		if not ALPHABET.contains(character):
			return ""
		clean += character
	return clean if clean.length() == LENGTH else ""


static func is_valid(text: String) -> bool:
	return not normalize(text).is_empty()


## "abc-def", for showing.
static func pretty(code: String) -> String:
	var groups: PackedStringArray = []
	for start in range(0, code.length(), 3):
		groups.append(code.substr(start, 3))
	return "-".join(groups)


## The link to a room, with the code written the way it is shown ("abc-def").
static func link_for(page_url: String, code: String) -> String:
	return "%s#%s=%s" % [page_url.get_slice("#", 0), LINK_KEY, pretty(normalize(code))]
