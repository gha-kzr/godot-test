class_name AchievementsScreen
extends Screen
## Every achievement with what to do, the unlocked ones lit, and the count. The back arrow (or Esc)
## returns to the hub.

const LOCKED_COLOR := Color(1.0, 1.0, 1.0, 0.45)
## Unlocked names are gold.
const UNLOCKED_COLOR := Color(1.0, 0.78, 0.25)

@onready var _back: Button = %BackButton
@onready var _count: Label = %Count
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_back.pressed.connect(back_pressed.emit)


func show_achievements(profile: Profile) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var unlocked := 0
	for achievement in Achievements.all():
		var done := achievement.id() in profile.achievements
		unlocked += 1 if done else 0
		var row := VBoxContainer.new()
		row.name = "Row_%s" % achievement.id()
		var name_label := Label.new()
		name_label.text = tr(achievement.display_name)
		name_label.theme_type_variation = &"PromptLabel"
		if done:
			name_label.add_theme_color_override("font_color", UNLOCKED_COLOR)
		var text := Label.new()
		text.text = tr(achievement.description)
		text.theme_type_variation = &"SmallLabel"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for label: Label in [name_label, text]:
			label.modulate = Color.WHITE if done else LOCKED_COLOR
			row.add_child(label)
		_list.add_child(row)
	_count.text = tr("%d / %d unlocked") % [unlocked, Achievements.all().size()]
