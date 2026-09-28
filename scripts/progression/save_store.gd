class_name SaveStore
extends RefCounted
## Reads and writes the profile as JSON. A missing, unreadable or newer save never
## crashes the game: it starts a fresh profile instead (with a warning). An unreadable save
## is first moved aside (profile.json.<time>.bak), so it's never silently overwritten; a
## save from a newer version is left alone and this store refuses to overwrite it.

const DEFAULT_PATH := "user://profile.json"

var path := DEFAULT_PATH
## Set when the save on disk is from a newer version of the game: never overwrite it.
var read_only := false


func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path


## Writes to a temporary file first, then swaps it in, so a crash mid-write can't leave
## a half-written save. Returns false (with an error) if writing failed.
func save(profile: Profile) -> bool:
	if read_only:
		push_warning("SaveStore: %s is from a newer version of the game; not overwriting it" % path)
		return false
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveStore: can't write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("SaveStore: writing %s failed (%s); the previous save is kept" % [temp_path, error_string(write_error)])
		return false
	var error := DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("SaveStore: can't replace %s (%s)" % [path, error_string(error)])
		return false
	return true


func load_or_create(roster: Roster) -> Profile:
	if not FileAccess.file_exists(path):
		return Profile.create(roster)
	var json := JSON.new()  # parse() reports errors quietly, unlike JSON.parse_string().
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if parsed is not Dictionary:
		push_warning("SaveStore: %s is unreadable; moved to %s, starting a fresh profile" % [path, _back_up()])
		return Profile.create(roster)
	var profile := Profile.from_dict(parsed, roster)
	if profile == null:
		read_only = true
		push_warning("SaveStore: %s is from a newer version; playing on a fresh profile that won't be saved" % path)
		return Profile.create(roster)
	return profile


## Moves the current save aside and returns where it went.
func _back_up() -> String:
	var backup := "%s.%d.bak" % [path, int(Time.get_unix_time_from_system())]
	DirAccess.rename_absolute(path, backup)
	return backup


func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
