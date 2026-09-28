extends TestCase
## The game root: party screen ↔ battle, rewards applied and saved after a battle.

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const SAVE := "user://test_game/profile.json"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Game:
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	SaveStore.new(SAVE).delete()
	var game := GAME_SCENE.instantiate() as Game
	game.save_path = SAVE
	game.rng_seed = 5
	_tree().root.add_child(game)
	return game


func after_each_clean() -> void:
	SaveStore.new(SAVE).delete()
	DirAccess.remove_absolute(SAVE.get_base_dir())


func _battle(game: Game) -> BattleController:
	game.start_battle()
	return game.screen as BattleController


func _end(battle: BattleController, players_win: bool) -> void:
	for unit in battle.battle.state.units:
		if (unit.team == UnitState.Team.ENEMY) == players_win:
			unit.hp = 0


func test_the_game_opens_on_the_party_screen() -> void:
	var game := _game()
	assert_true(game.screen is PartyScreen)
	assert_eq(game.profile.party, [0, 1] as Array[int])
	after_each_clean()

func test_a_battle_is_built_from_the_profile() -> void:
	var game := _game()
	game.profile.heroes[0].level = 3
	var battle := _battle(game)
	assert_true(game.screen is BattleController)
	assert_false(battle.standalone)
	var knight := battle.battle.state.units[0]
	assert_eq(knight.data.display_name, "Knight")
	assert_eq(knight.max_hp(), 48, "40 + 2 levels x 4 HP")
	assert_eq(knight.data.spells.size(), 4, "Whirlwind unlocked")
	assert_eq((battle.hud.get_node("%RestartButton") as Button).text, "Continue")
	after_each_clean()

func test_a_won_battle_grants_xp_and_loot_and_saves() -> void:
	var game := _game()
	var battle := _battle(game)
	_end(battle, true)
	var expected := BattleRewards.compute(battle.battle.state)
	(battle.hud.get_node("%RestartButton") as Button).pressed.emit()  # "Continue".
	assert_true(game.screen is PartyScreen, "back to the party")
	assert_eq(game.profile.heroes[0].xp, 27, "Brute 15 + Archer 12")
	assert_eq(game.profile.heroes[1].xp, 27)
	assert_eq(game.profile.heroes[0].level, 2)
	assert_eq(game.profile.stash.size(), expected.runes.size())
	var summary := (game.screen.get_node("%Summary") as Label).text
	assert_true(summary.begins_with("Victory! +27 XP"), summary)
	assert_true(summary.contains("Knight reached level 2."), summary)
	var saved := SaveStore.new(SAVE).load_or_create(game.roster)
	assert_eq(saved.heroes[0].xp, 27, "saved")
	assert_eq(saved.stash.size(), expected.runes.size())
	after_each_clean()

func test_a_lost_battle_grants_nothing() -> void:
	var game := _game()
	var battle := _battle(game)
	_end(battle, false)
	battle.battle_finished.emit(battle.battle.state)
	assert_eq(game.profile.heroes[0].xp, 0)
	assert_eq(game.profile.stash.size(), 0)
	assert_true((game.screen.get_node("%Summary") as Label).text.begins_with("Defeat"))
	after_each_clean()

func test_progress_carries_into_the_next_game_session() -> void:
	var game := _game()
	var battle := _battle(game)
	_end(battle, true)
	battle.battle_finished.emit(battle.battle.state)
	game.free()
	var reopened := GAME_SCENE.instantiate() as Game
	reopened.save_path = SAVE
	_tree().root.add_child(reopened)
	assert_eq(reopened.profile.heroes[0].xp, 27, "loaded from the save")
	after_each_clean()

func test_equip_requests_go_through_the_game_and_save() -> void:
	var game := _game()
	game.profile.stash = [load("res://data/runes/might.tres")] as Array[RuneData]
	var party := game.screen as PartyScreen
	party.equip_requested.emit(0, 0)
	assert_eq(game.profile.heroes[0].runes[0].display_name, "Rune of Might")
	assert_eq(SaveStore.new(SAVE).load_or_create(game.roster).heroes[0].runes[0].display_name, "Rune of Might")
	party.unequip_requested.emit(0, 0)
	assert_eq(game.profile.stash.size(), 1)
	party.unequip_requested.emit(0, 0)
	assert_true((party.get_node("%Summary") as Label).text.contains("empty"), "errors are shown")
	after_each_clean()

func test_the_standalone_battle_scene_still_plays_again() -> void:
	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate() as BattleController
	battle.rng_seed = 3
	_tree().root.add_child(battle)
	assert_true(battle.standalone)
	assert_eq((battle.hud.get_node("%RestartButton") as Button).text, "Play again")
	var first := battle.battle
	(battle.hud.get_node("%RestartButton") as Button).pressed.emit()
	assert_ne(battle.battle, first, "a new battle")
	after_each_clean()

func test_rewards_are_saved_as_soon_as_the_battle_ends() -> void:
	var game := _game()
	var battle := _battle(game)
	_end(battle, true)
	battle._begin_next()  # The battle notices it's over and shows the result screen.
	assert_eq(battle.input_state, BattleController.State.ENDED)
	assert_eq(game.profile.heroes[0].xp, 27, "applied before Continue")
	assert_eq(SaveStore.new(SAVE).load_or_create(game.roster).heroes[0].xp, 27, "already saved")
	battle.battle_finished.emit(battle.battle.state)
	assert_eq(game.profile.heroes[0].xp, 27, "not rewarded twice")
	after_each_clean()

func test_a_party_that_cant_fit_the_map_stays_on_the_party_screen() -> void:
	var game := _game()
	game.profile.unlocked.append(2)
	game.profile.party = [0, 1, 2] as Array[int]  # The slice map has 2 player spawns.
	game.start_battle()
	assert_true(game.screen is PartyScreen)
	assert_true((game.screen.get_node("%Summary") as Label).text.contains("1 to 2 heroes"))
	after_each_clean()
