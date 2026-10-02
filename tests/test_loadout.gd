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


func _screen(profile: Profile) -> PartyScreen:
	var screen := PARTY_SCENE.instantiate() as PartyScreen
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.show_profile(profile)
	return screen


func test_the_party_screen_asks_for_a_swap_then_a_replacement() -> void:
	var profile := _profile()
	profile.heroes[0].level = 12
	var screen := _screen(profile)
	var asks: Array = []
	screen.loadout_requested.connect(func(hero: int, slot: int, spell: SpellData) -> void:
		asks.append([hero, slot, spell.display_name]))
	var slots := screen.find_child("Spells", true, false)
	assert_eq(slots.get_child_count(), HeroRecord.LOADOUT_SLOTS)
	assert_eq((slots.get_child(0) as Button).text, "1. A")
	(slots.get_child(0) as Button).pressed.emit()
	assert_true((screen.find_child("SpellInfo", true, false) as Label).text.contains("AP"), "the picked spell's description")
	(slots.get_child(2) as Button).pressed.emit()
	assert_eq(asks, [[0, 0, "C"]], "slot 1 takes C: a swap")
	var inactive := screen.find_child("InactiveSpells", true, false)
	assert_eq(inactive.get_child_count(), 2, "F and G")
	(inactive.get_child(0) as Button).pressed.emit()
	assert_eq(asks.size(), 1, "no slot picked: only the description")
	(slots.get_child(4) as Button).pressed.emit()
	(inactive.get_child(1) as Button).pressed.emit()
	assert_eq(asks[1], [0, 4, "G"], "G into slot 5")
	screen.free()


func test_empty_slots_are_disabled() -> void:
	var screen := _screen(_profile())
	var slots := screen.find_child("Spells", true, false)
	assert_true((slots.get_child(2) as Button).disabled, "A and B only")
	assert_false((screen.find_child("InactiveTitle", true, false) as Label).visible, "nothing inactive")
	screen.free()
