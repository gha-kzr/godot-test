class_name MuteButton
extends Button
## The speaker icon always shown in a corner of the screen: one click mutes or unmutes all
## sound. It only shows and reports the state (`toggled`); the Game root owns the setting.
## Mouse only, so it never takes the keyboard focus the menus navigate with.

const SOUND_ON: Texture2D = preload("res://ui/icons/speaker.svg")
const SOUND_OFF: Texture2D = preload("res://ui/icons/speaker_off.svg")


func _init() -> void:
	name = "MuteButton"
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(48, 44)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_text = tr("Mute or unmute all sound")
	toggled.connect(_show_icon)
	_show_icon(false)


## Shows the state without reporting it.
func show_muted(muted: bool) -> void:
	set_pressed_no_signal(muted)
	_show_icon(muted)


func _show_icon(muted: bool) -> void:
	icon = SOUND_OFF if muted else SOUND_ON
