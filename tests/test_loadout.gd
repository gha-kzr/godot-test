extends TestCase
## The spell loadout: 5 active spells per hero, chosen on the party screen, saved.

const PARTY_SCENE := preload("res://scenes/game/party_screen.tscn")


static func _spell(spell_name: String) -> SpellData:
	var spell := BattleFixtures.damage_spell()
	spell.display_name = spell_name
	return spell


## A hero with spells A, B (base) and C at 2, D at 3, E at 4, F at 5, G at 12 (a milestone).
static func _hero() -> HeroData:
	var hero := HeroData.new()
	hero.unit = BattleFixtures.unit("Hero", 150, 3, 6, 30)
	hero.unit.spells = [_spell("A"), _spell("B")] as Array[SpellData]
	var rewards: Array[LevelReward] = []
	for spell_name in ["C", "D", "E", "F", "", "", "", ""]:
		var reward := LevelReward.new()
		if not spell_name.is_empty():
			reward.spells = [_spell(spell_name)] as Array[SpellData]
		rewards.append(reward)
	hero.level_rewards = rewards
	var milestone := LevelReward.new()
	milestone.spells = [_spell("G")] as Array[SpellData]
	hero.milestone_rewards = {12: milestone}
	return hero


static func _names(spells: Array[SpellData]) -> Array:
	return spells.map(func(spell: SpellData) -> String: return spell.display_name)


func _record(level: int) -> HeroRecord:
	var record := HeroRecord.new(_hero())
	record.level = level
	return record


func test_a_new_hero_has_its_known_spells_in_order_with_empty_slots_after() -> void:
	var record := _record(3)
	assert_eq(_names(record.spells()), ["A", "B", "C", "D"])
	record.settle_loadout()
	assert_eq(record.loadout.size(), HeroRecord.LOADOUT_SLOTS)
	assert_eq(record.loadout[4], null, "a free slot")


func test_a_learned_spell_takes_a_free_slot_and_later_ones_stay_inactive() -> void:
	var record := _record(4)
	assert_eq(_names(record.spells()), ["A", "B", "C", "D", "E"])
	record.level = 12
	assert_eq(_names(record.spells()), ["A", "B", "C", "D", "E"], "the loadout is full")
	assert_eq(_names(record.inactive_spells()), ["F", "G"], "the milestone's spell is learned too")


func test_slots_swap_and_inactive_spells_replace() -> void:
	var record := _record(12)
	var f := record.known_spells()[5]
	assert_eq(record.assign_spell(0, record.known_spells()[2]), "", "C into slot 0")
	assert_eq(_names(record.spells()), ["C", "B", "A", "D", "E"], "swapped with A")
	assert_eq(record.assign_spell(1, f), "")
	assert_eq(_names(record.spells()), ["C", "F", "A", "D", "E"], "F replaces B")
	assert_eq(_names(record.inactive_spells()), ["B", "G"])


func test_a_spell_can_never_be_removed() -> void:
	var record := _record(2)  # A, B, C: two free slots.
	assert_ne(record.assign_spell(3, record.known_spells()[0]), "", "an empty slot takes nothing")
	assert_ne(record.assign_spell(0, null), "")
	assert_ne(record.assign_spell(0, _spell("Unknown")), "", "an unknown spell")
	assert_eq(_names(record.spells()), ["A", "B", "C"])


func test_spells_it_no_longer_knows_leave_the_loadout() -> void:
	var record := _record(4)
	record.assign_spell(0, record.known_spells()[4])  # E first.
	record.level = 2
	assert_eq(_names(record.spells()), ["B", "C", "A"], "E (which swapped with A) is not known at level 2: the rest close up")


func test_the_battle_unit_has_the_loadout_in_slot_order() -> void:
	var record := _record(4)
	record.assign_spell(0, record.known_spells()[3])
	assert_eq(_names(record.battle_unit_data().spells), ["D", "B", "C", "A", "E"])


func _profile() -> Profile:
	var roster := Roster.new()
	roster.heroes = [_hero()] as Array[HeroData]
	roster.starting_unlocked = [0] as Array[int]
	roster.starting_party = [0] as Array[int]
	roster.config = ProgressionConfig.new()
	return Profile.create(roster)


func test_the_profile_assigns_and_levels_up_into_free_slots() -> void:
	var profile := _profile()
	var record := profile.heroes[0]
	assert_eq(profile.assign_spell(0, 1, record.known_spells()[0]), "")
	assert_eq(_names(record.spells()), ["B", "A"])
	assert_ne(profile.assign_spell(0, 4, record.known_spells()[0]), "", "an empty slot")
	var rewards := BattleRewards.new()
	rewards.xp = 50  # Level 3.
	profile.apply_rewards(rewards)
	assert_eq(_names(record.spells()), ["B", "A", "C", "D"], "new spells fill free slots")
	assert_eq(record.loadout[2].display_name, "C", "settled")


func test_the_loadout_is_saved_with_the_shipped_heroes() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	var profile := Profile.create(roster)
	var knight := profile.heroes[0]
	knight.xp = roster.config.xp_for_level(3)
	knight.level = 3
	var last := knight.spells().back() as SpellData
	assert_eq(profile.assign_spell(0, 0, last), "")
	var loaded := Profile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())), roster)
	assert_eq(loaded.heroes[0].spells(), knight.spells(), "the order survives a save")
	assert_eq(loaded.heroes[0].spells()[0], last)


func test_a_save_without_a_loadout_gets_the_default_one() -> void:
	var roster := load("res://data/progression/roster.tres") as Roster
	var data := Profile.create(roster).to_dict()
	for entry: Dictionary in data["heroes"]:
		entry.erase("loadout")
	var loaded := Profile.from_dict(data, roster)
	assert_eq(loaded.heroes[0].spells(), loaded.heroes[0].known_spells())


const SPELLS_SCENE := preload("res://scenes/game/spells_screen.tscn")


func _spells_screen(record: HeroRecord) -> SpellsScreen:
	var screen := SPELLS_SCENE.instantiate() as SpellsScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_spells(record)
	return screen


static func _button(row: Node, button_name: String) -> Button:
	return row.find_child(button_name, true, false) as Button


func test_the_spells_screen_shows_every_description_and_reading_moves_nothing() -> void:
	var profile := _profile()
	profile.heroes[0].level = 12
	var screen := _spells_screen(profile.heroes[0])
	var asks: Array = []
	screen.assign_requested.connect(func(slot: int, spell: SpellData) -> void: asks.append([slot, spell.display_name]))
	for slot in HeroRecord.LOADOUT_SLOTS:
		var row := screen.find_child("Slot%d" % (slot + 1), true, false)
		assert_true(row != null, "slot %d" % (slot + 1))
		assert_true((row.find_child("Description", true, false) as Label).text.contains("Range"), "its description is shown")
	assert_true(screen.find_child("Known_F", true, false) != null, "F is known, not active")
	assert_true(screen.find_child("Known_G", true, false) != null)
	assert_eq(asks, [], "nothing changes by reading")
	screen.free()


func test_move_then_put_here_swaps_or_replaces() -> void:
	var profile := _profile()
	profile.heroes[0].level = 12
	var screen := _spells_screen(profile.heroes[0])
	var asks: Array = []
	screen.assign_requested.connect(func(slot: int, spell: SpellData) -> void: asks.append([slot, spell.display_name]))
	_button(screen.find_child("Slot3", true, false), "Move").pressed.emit()  # C.
	assert_eq(screen.moving.display_name, "C")
	assert_true(_button(screen.find_child("Slot3", true, false), "Cancel") != null, "its own row cancels")
	assert_true(_button(screen.find_child("Known_F", true, false), "PutHere") == null, "an inactive spell isn't a destination")
	_button(screen.find_child("Slot1", true, false), "PutHere").pressed.emit()
	assert_eq(asks, [[0, "C"]], "C into slot 1: a swap with A")
	screen.show_spells(profile.heroes[0])
	_button(screen.find_child("Known_G", true, false), "Move").pressed.emit()
	_button(screen.find_child("Slot5", true, false), "PutHere").pressed.emit()
	assert_eq(asks[1], [4, "G"], "G replaces slot 5")
	screen.free()


func test_esc_cancels_a_move_before_going_back() -> void:
	var profile := _profile()
	profile.heroes[0].level = 12
	var screen := _spells_screen(profile.heroes[0])
	var backs := {"count": 0}
	screen.back_pressed.connect(func() -> void: backs.count += 1)
	_button(screen.find_child("Slot2", true, false), "Move").pressed.emit()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_eq(screen.moving, null, "the move is cancelled")
	assert_eq(backs.count, 0)
	screen._unhandled_input(esc)
	assert_eq(backs.count, 1, "then Esc goes back")
	screen.free()


func test_empty_slots_show_as_empty() -> void:
	var screen := _spells_screen(_profile().heroes[0])  # A and B only.
	var empty := screen.find_child("Slot3", true, false)
	assert_eq((empty.find_child("Name", true, false) as Label).text, "(empty)")
	assert_true(_button(empty, "Move") == null)
	screen.free()


func test_the_hub_lists_the_active_spells_and_opens_the_spells_screen() -> void:
	var profile := _profile()
	profile.heroes[0].level = 12
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile)
	assert_eq(screen.find_child("Spells", true, false).get_child_count(), HeroRecord.LOADOUT_SLOTS)
	var change := screen.find_child("ChangeSpellsButton", true, false) as Button
	assert_eq(change.text, "Change spells (2 more known)")
	var asked: Array[int] = []
	screen.spells_pressed.connect(func(hero: int) -> void: asked.append(hero))
	change.pressed.emit()
	assert_eq(asked, [0] as Array[int])
	screen.free()
