class_name PartyScreen
extends Screen
## The hub between runs, one screen: hero tabs (left), the selected hero's stats, spells and
## rune slots (centre), the shared rune stash (right) and where to fight next (bottom). It
## is a facade over four component scenes: it reads the profile to display it and passes
## their choices up as signals; the Game root applies them (then calls show_profile).
## Esc (back) returns to the title.

signal achievements_pressed
signal tower_pressed(start_floor: int)
signal stage_pressed(stage_index: int)
signal continue_pressed
signal abandon_pressed
signal equip_requested(hero_index: int, stash_index: int)
signal unequip_requested(hero_index: int, slot: int)
## A hero's spells screen is wanted (to read them all and change the loadout).
signal spells_pressed(hero_index: int)
## A rune of the stash is to be thrown away for good (after its inline Yes).
signal drop_requested(stash_index: int)
## The player picked a hero's tab (the Game keeps it across screens).
signal hero_selected(hero_index: int)
## The hint card was dismissed.
signal hint_dismissed
## A tutorial step was finished or skipped (the Game root saves the settings).
signal tutorial_changed

## The hero whose details are shown (a roster index).
var selected_hero := 0
## The guided first steps (null: none); the Game root hands it in before show_profile().
var tutorial: Tutorial
var _step: Dictionary = {}
var _tutorial_overlay: TutorialOverlay
var _profile: Profile
var _tower: TowerConfig

@onready var _summary: Label = %Summary
@onready var _tabs: HeroTabs = %HeroTabs
@onready var _panel: HeroPanel = %HeroPanel
@onready var _stash: RuneStash = %RuneStash
@onready var _destinations: DestinationBar = %DestinationBar
@onready var _hint_card: HintCard = %HintCard
@onready var _menu_button: Button = %MenuButton
@onready var _achievements_button: Button = %AchievementsButton


func _ready() -> void:
	_menu_button.pressed.connect(back_pressed.emit)
	_achievements_button.pressed.connect(achievements_pressed.emit)
	_hint_card.dismissed.connect(hint_dismissed.emit)
	_tutorial_overlay = TutorialOverlay.new()
	_tutorial_overlay.block_cancel = true  # Esc would leave for the title, mid-step.
	_tutorial_overlay.skipped.connect(_skip_tutorial)
	add_child(_tutorial_overlay)
	_tabs.hero_selected.connect(select_hero)
	_panel.unequip_requested.connect(func(slot: int) -> void: unequip_requested.emit(selected_hero, slot))
	_panel.spells_requested.connect(func() -> void: spells_pressed.emit(selected_hero))
	_stash.equip_requested.connect(func(index: int) -> void:
		_on_equip_for_tutorial()
		equip_requested.emit(selected_hero, index))
	_stash.drop_requested.connect(drop_requested.emit)
	_destinations.tower_pressed.connect(tower_pressed.emit)
	_destinations.stage_pressed.connect(stage_pressed.emit)
	_destinations.continue_pressed.connect(continue_pressed.emit)
	_destinations.abandon_pressed.connect(abandon_pressed.emit)


## `summary`: what the last run brought ("" for none); `message`: e.g. an equip error;
## `tower`: the tower and stages to offer (none: no destinations).
func show_profile(profile: Profile, summary := "", message := "", tower: TowerConfig = null) -> void:
	var focused := _focused_name()
	_profile = profile
	if tower != null:
		_tower = tower
	if not profile.is_unlocked(selected_hero):
		selected_hero = profile.party[0] if not profile.party.is_empty() else 0
	_summary.text = "\n".join([summary, message].filter(func(t: String) -> bool: return not t.is_empty()))
	_summary.visible = not _summary.text.is_empty()
	_tabs.show_heroes(profile, selected_hero)
	_panel.show_hero(profile, selected_hero)
	_stash.show_stash(profile)
	_destinations.show_destinations(profile, _tower)
	_restore_focus.call_deferred(focused)
	_refresh_tutorial()


## The rune step: when the stash holds a rune and no hero wears one yet, light the stash and
## wait for the equip (a player who already equips runes, e.g. after "Show hints again", knows how).
func _refresh_tutorial() -> void:
	_step = {}
	_tutorial_overlay.clear()
	if tutorial == null or _profile == null or _profile.stash.is_empty() or _wears_a_rune():
		return
	var step := tutorial.next_step(Tutorial.HUB_STEPS)
	if step.is_empty():
		return
	_step = step
	_tutorial_overlay.show_step(Tutorial.text_of(step), _stash.get_global_rect())


func _wears_a_rune() -> bool:
	return _profile.heroes.any(func(hero: HeroRecord) -> bool: return hero.runes.any(func(r: RuneData) -> bool: return r != null))


## Whether the tutorial is lighting something now (a tip card would fight with its dim).
func has_tutorial_step() -> bool:
	return not _step.is_empty()


func _process(_delta: float) -> void:
	if not _step.is_empty():
		_tutorial_overlay.set_hole(_stash.get_global_rect())  # The layout settles after the first frame.


func _on_equip_for_tutorial() -> void:
	if not _step.is_empty() and _step["awaits"] == Tutorial.Action.EQUIP_RUNE:
		tutorial.complete(_step["id"])
		_step = {}
		_tutorial_overlay.clear()
		tutorial_changed.emit()


func _skip_tutorial() -> void:
	if tutorial != null:
		tutorial.skip_all()
		_step = {}
		_tutorial_overlay.clear()
		tutorial_changed.emit()


## The name of the control holding keyboard focus inside this screen ("" for none).
func _focused_name() -> StringName:
	var owner_control := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return owner_control.name if owner_control != null and is_ancestor_of(owner_control) else &""


## Rebuilding replaced the focused button: focus its namesake, else the first control.
func _restore_focus(focused: StringName) -> void:
	if not is_inside_tree() or focused == &"":
		return
	var again := find_child(focused, true, false) as Control
	# A rune left the stash, so its buttons are gone: land on the row that took its place.
	var stash_row := RegEx.create_from_string("^(?:Stash|Drop|DropYes|DropNo)([0-9]+)$").search(String(focused))
	if again == null and stash_row != null and _stash.focus_row(int(stash_row.get_string(1))):
		return
	if again != null and again.focus_mode == Control.FOCUS_ALL and again.is_visible_in_tree():
		again.grab_focus()
	else:
		focus_first()


## Shows a dismissable hint card; it lights the destinations (the tower and the stages).
func show_hint(text: String) -> void:
	_hint_card.show_hint(text, HintCard.around(_destinations))


func select_hero(hero_index: int) -> void:
	selected_hero = hero_index
	_tabs.set_selected(hero_index)
	_panel.show_hero(_profile, hero_index)
	hero_selected.emit(hero_index)
