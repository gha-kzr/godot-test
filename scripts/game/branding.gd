class_name Branding
extends RefCounted
## The game's own artwork, optional: a logo and a title picture dropped in ui/branding/ (see its
## README; png or jpg). Missing files simply mean the text title. The picture is expected to carry
## the game's name itself, so the title screen shows it instead of the text.

const DIRECTORY := "res://ui/branding"
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]


static func logo() -> Texture2D:
	return _find("logo")


static func title_image() -> Texture2D:
	return _find("title_image")


static func _find(base_name: String) -> Texture2D:
	for extension in EXTENSIONS:
		var path := "%s/%s.%s" % [DIRECTORY, base_name, extension]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
