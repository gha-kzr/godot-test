extends TestCase
## The rune stash on the hub, clicked the way a player does: which row a Salvage asks about when
## several runes are the same resource, rows that keep their height and the scroll where it was,
## what the Fuse button says, flat runes that have no levels, and the hub fitting a small window.

const PARTY_SCENE := preload("res://scenes/game/party_screen.tscn")
const MIGHT := "res://data/runes/might.tres"
const FOCUS := "res://data/runes/focus.tres"          # +1 AP and +5 Power: levels change the Power.
const SWIFTNESS := "res://data/runes/swiftness.tres"  # +1 MP only: flat.


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _screen(profile: Profile) -> PartyScreen:
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile)
	return screen


func _profile(runes: Array[RuneData], essence := 0) -> Profile:
	var profile := Profile.create(load("res://data/progression/roster.tres") as Roster)
	profile.stash.assign(runes)
	profile.essence = essence
	return profile


func _rune(path: String) -> RuneData:
	return load(path) as RuneData


func _press(screen: Node, button_name: String) -> void:
	(screen.find_child(button_name, true, false) as Button).pressed.emit()


func test_copies_of_one_rune_ask_about_the_row_that_was_clicked() -> void:
	var might := _rune(MIGHT)
	var screen := _screen(_profile([might, might, might, might] as Array[RuneData]))
	_press(screen, "Salvage2")  # The third copy: the same resource as the first.
	assert_true(screen.find_child("SalvageQuestion2", true, false) != null, "the question is on the clicked row")
	for other in [0, 1, 3]:
		assert_true(screen.find_child("SalvageQuestion%d" % other, true, false) == null, "and only there (%d)" % other)
		assert_true(screen.find_child("Stash%d" % other, true, false) != null, "the others are untouched (%d)" % other)
	var asked: Array[int] = []
	screen.salvage_requested.connect(func(index: int) -> void: asked.append(index))
	_press(screen, "SalvageYes2")
	assert_eq(asked, [2] as Array[int], "Yes salvages that row")
	screen.free()


func test_asking_about_another_copy_moves_the_question() -> void:
	var might := _rune(MIGHT)
	var screen := _screen(_profile([might, might, might] as Array[RuneData]))
	_press(screen, "Salvage0")
	_press(screen, "SalvageNo0")
	_press(screen, "Salvage1")
	assert_true(screen.find_child("SalvageQuestion1", true, false) != null)
	assert_true(screen.find_child("SalvageQuestion0", true, false) == null, "No closed the first question")
	screen.free()


func test_the_question_follows_its_copy_when_the_list_changes() -> void:
	var might := _rune(MIGHT)
	var profile := _profile([_rune(FOCUS), might, might, might] as Array[RuneData])
	var screen := _screen(profile)
	_press(screen, "Salvage3")
	profile.stash.remove_at(0)  # E.g. an equip of the first rune: the asked copy moves up one row.
	screen.show_profile(profile)
	assert_eq(screen.get_node("%RuneStash").asking_index(), 2)
	assert_true(screen.find_child("SalvageQuestion2", true, false) != null)
	screen.free()


func test_a_question_row_is_as_tall_as_the_row_it_replaces() -> void:
	var stash: Array[RuneData] = []
	for i in 6:
		stash.append(_rune(MIGHT))
	var screen := _screen(_profile(stash))
	await _frame()
	await _frame()
	var before := (screen.find_child("Row2", true, false) as Control).size.y
	var below := (screen.find_child("Row3", true, false) as Control).global_position.y
	_press(screen, "Salvage2")
	await _frame()
	await _frame()
	assert_eq((screen.find_child("Row2", true, false) as Control).size.y, before, "same height")
	assert_eq((screen.find_child("Row3", true, false) as Control).global_position.y, below, "nothing below moves")
	screen.free()


func test_the_scroll_stays_where_it_was_when_the_list_is_rebuilt() -> void:
	var stash: Array[RuneData] = []
	for i in 30:
		stash.append(_rune(MIGHT))
	var screen := _screen(_profile(stash))
	await _frame()
	await _frame()
	var scroll := screen.find_child("StashScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 500
	await _frame()
	var before := scroll.scroll_vertical
	assert_true(before > 0, "the list is long enough to scroll")
	_press(screen, "Salvage9")
	await _frame()
	await _frame()
	assert_eq(scroll.scroll_vertical, before, "the question opened without moving the list")
	_press(screen, "SalvageNo9")
	await _frame()
	await _frame()
	assert_eq(scroll.scroll_vertical, before, "and closing it too")
	screen.free()


func test_the_fuse_button_says_what_is_missing() -> void:
	var might := _rune(MIGHT)
	var profile := _profile([might, might, RuneData.leveled(might, 2)] as Array[RuneData], 3)
	var screen := _screen(profile)
	var two := screen.find_child("Fuse0", true, false) as Button
	assert_eq(two.text, "Need 3 (have 2)")
	assert_true(two.disabled)
	assert_true(two.tooltip_text.contains("3"), "the tooltip says why")
	profile.stash.append(might)
	screen.show_profile(profile)
	var no_essence := screen.find_child("Fuse0", true, false) as Button
	assert_eq(no_essence.text, "Need 10 essence", "three copies, not enough essence")
	assert_true(no_essence.disabled)
	profile.essence = 10
	screen.show_profile(profile)
	var ready := screen.find_child("Fuse0", true, false) as Button
	assert_eq(ready.text, "Fuse to level 2")
	assert_false(ready.disabled)
	screen.free()


func test_a_rune_with_only_flat_effects_has_no_levels_and_no_fuse() -> void:
	var swiftness := _rune(SWIFTNESS)
	assert_false(swiftness.can_level())
	assert_true(_rune(FOCUS).can_level(), "its Power part grows")
	assert_true(RuneData.leveled(swiftness, 5) == swiftness, "it stays level 1")
	var profile := _profile([swiftness, swiftness, swiftness] as Array[RuneData], 99)
	assert_false(profile.fuse(0).is_empty(), "nothing to fuse")
	var screen := _screen(profile)
	assert_true(screen.find_child("Fuse0", true, false) == null, "no Fuse button")
	assert_true(screen.find_child("Salvage0", true, false) != null, "but it can be salvaged")
	screen.free()


func test_the_hub_fits_a_small_window_even_with_long_rune_names() -> void:
	var profile := _profile([] as Array[RuneData])
	for path in ["res://data/runes/fire_ward.tres", "res://data/runes/venom_ward.tres", "res://data/runes/stone_skin.tres"]:
		for i in 6:
			profile.stash.append(RuneData.leveled(_rune(path), 1 + i))
	for slot in HeroRecord.RUNE_SLOTS:
		profile.heroes[0].runes[slot] = RuneData.leveled(_rune("res://data/runes/venom_ward.tres"), 4)
	var screen := _screen(profile)
	await _frame()
	await _frame()
	var needed := (screen.find_child("Rows", true, false) as Control).get_combined_minimum_size().x + 48.0
	assert_true(needed <= 1000.0, "the hub needs %d px wide, a small window has about 1000" % needed)
	screen.free()
