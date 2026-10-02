class_name AudioService
extends Node
## Plays the game's sounds and music through two buses under Master, "Music" and "Effects"
## (created here when missing). Views and screens only ask for a sound by event name (signals
## up: the Game root connects them to play_sfx), so nothing else knows about audio. Sound
## effects use a small pool of players; music cross-fades between two. Volumes come from
## Settings (SettingsApplier.apply_audio). Browsers only start audio after a click, which the
## title's Play press provides.

const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
## Sound events that take the stage alone: the music fades out when one plays (the next screen
## brings its own music back).
const STINGERS: Array[StringName] = [&"victory", &"defeat"]
## How long a still-playing stinger takes to fade out when the next music starts.
const STINGER_CUT := 0.4
const POOL_SIZE := 8
const CROSSFADE := 0.8
const SILENT_DB := -60.0

@export var audio_set: AudioSet

## The last sound events asked for and the track now playing, for tests and debugging.
var requested: Array[StringName] = []
var current_music: StringName = &""

## Event → the time (msec) it last played, for the cooldowns.
var _last_played: Dictionary[StringName, int] = {}
## The player of the stinger now playing, if any: new music cuts it off.
var _stinger: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
var _fade: Tween


## Makes sure the Music and Effects buses exist (as sends to Master). Safe to call many times.
static func ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, MASTER_BUS)


## Sets a bus's loudness from a 0..1 slider value (0 is silent).
static func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_db(index, SILENT_DB if linear <= 0.001 else linear_to_db(clampf(linear, 0.0, 1.0)))


func _ready() -> void:
	ensure_buses()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS_BUS
		add_child(player)
		_pool.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)


## Plays a sound event (an AudioSet.SFX_EVENTS name). Unknown or missing ones are skipped.
func play_sfx(event: StringName) -> void:
	requested.append(event)
	if requested.size() > 32:
		requested.pop_front()
	if audio_set == null or not audio_set.sfx.has(event) or _pool.is_empty():
		return
	if event in STINGERS:
		stop_music()  # The fanfare is heard on its own, not over the battle music.
	var now := Time.get_ticks_msec()
	if now - _last_played.get(event, -1_000_000) < audio_set.sfx_cooldown.get(event, 0.0) * 1000.0:
		return
	_last_played[event] = now
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = audio_set.sfx[event]
	player.volume_db = audio_set.sfx_gain_db.get(event, 0.0)
	var variation: float = audio_set.sfx_pitch_variation.get(event, 0.0)
	player.pitch_scale = 1.0 + randf_range(-variation, variation)
	player.play()
	if event in STINGERS:
		_stinger = player


## Plays a music track on a loop, fading out the previous one. The same track again does
## nothing; an unknown one fades the music out.
func play_music(track: StringName) -> void:
	if track == current_music:
		return
	if track != &"":
		_cut_stinger()  # A new screen's music doesn't play over the fanfare of the last one.
	current_music = track
	var stream: AudioStream = audio_set.music.get(track) if audio_set != null else null
	var outgoing := _music_players[_music_active]
	_music_active = 1 - _music_active
	var incoming := _music_players[_music_active]
	if _fade != null:
		_fade.kill()
	# The player taking over may still be fading out an older track: it ends now.
	incoming.stop()
	incoming.volume_db = SILENT_DB
	_fade = create_tween().set_parallel()
	_fade.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
	if stream != null:
		make_loop(stream)
		incoming.stream = stream
		incoming.play()
		_fade.tween_property(incoming, "volume_db", 0.0, CROSSFADE)  # Both fade at once: a cross-fade.
	_fade.chain().tween_callback(outgoing.stop)


## Fades the stinger out quickly (it is a long fanfare; the player has moved on).
func _cut_stinger() -> void:
	var player := _stinger
	_stinger = null
	if player == null or not player.playing:
		return
	create_tween().tween_property(player, "volume_db", SILENT_DB, STINGER_CUT).finished.connect(player.stop)


## Sets a music stream to loop (each stream type has its own switch).
static func make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func stop_music() -> void:
	play_music(&"")


## Every button that appears anywhere in the game clicks when pressed (one hook, so screens
## need no sound code).
func hook_buttons(tree: SceneTree) -> void:
	tree.node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"audio_hooked"):
		node.set_meta(&"audio_hooked", true)
		(node as BaseButton).pressed.connect(play_sfx.bind(&"ui_click"))
