extends TestCase
## The game root: the hub, tower and stage runs through the director, the run screen
## between floors, boss choices, saving and resuming.

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const SAVE := "user://test_game/profile.json"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Game:
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	SaveStore.new(SAVE).delete()
	return _open()


func _open() -> Game:
	var game := GAME_SCENE.instantiate() as Game
	game.save_path = SAVE
	game.rng_seed = 5
	_tree().root.add_child(game)
	return game


func after_each_clean() -> void:
	SaveStore.new(SAVE).delete()
	DirAccess.remove_absolute(SAVE.get_base_dir())


func _saved(game: Game) -> Profile:
	return SaveStore.new(SAVE).load_or_create(game.roster)


func _press(screen: Node, button_name: String) -> void:
	(screen.find_child(button_name, true, false) as Button).pressed.emit()


func _battle(game: Game) -> BattleController:
	return game.screen as BattleController


## Ends the current battle, then closes its result screen ("Continue").
func _finish(game: Game, players_win: bool) -> BattleState:
	var battle := _battle(game)
	for unit in battle.battle.state.units:
		if (unit.team == UnitState.Team.ENEMY) == players_win:
			unit.hp = 0
	var state := battle.battle.state
	(battle.hud.get_node("%RestartButton") as Button).pressed.emit()
	return state


func _lines(game: Game) -> String:
	return (game.screen.get_node("%Lines") as Label).text


func test_the_game_opens_on_the_hub_with_the_three_heroes() -> void:
	var game := _game()
	assert_true(game.screen is PartyScreen)
	assert_eq(game.profile.party, [0, 1, 2] as Array[int])
	assert_true(game.screen.find_child("TowerButton", true, false) != null)
	assert_false((game.screen.find_child("Stage0", true, false) as Button).disabled)
	assert_true((game.screen.find_child("Stage1", true, false) as Button).disabled, "locked until stage 1 is cleared")
	assert_eq(game.screen.find_child("ContinueButton", true, false), null, "no run to continue")
	after_each_clean()

func test_the_tower_starts_a_run_at_floor_one() -> void:
	var game := _game()
	_press(game.screen, "TowerButton")
	var battle := _battle(game)
	assert_true(battle != null, "a battle")
	assert_false(battle.standalone)
	assert_eq(battle.battle_title, "Floor 1")
	assert_eq(battle.battle.state.units.filter(func(u: UnitState) -> bool: return u.team == UnitState.Team.PLAYER).size(), 3)
	assert_eq(battle.battle.sudden_death_round, game.tower.sudden_death_round)
	assert_true((battle.hud.get_node("%RoundLabel") as Label).text.begins_with("Floor 1 · Round"))
	assert_eq(_saved(game).run.floor_number, 1, "the run is saved as it starts")
	after_each_clean()

func test_a_won_floor_shows_the_run_screen_then_the_next_floor() -> void:
	var game := _game()
	game.start_tower(1)
	var state := _finish(game, true)
	var xp := BattleRewards.compute(state).xp
	assert_true(game.screen is RunScreen)
	assert_true(_lines(game).begins_with("+%d XP" % xp), _lines(game))
	assert_eq(game.profile.heroes[0].xp, xp)
	assert_eq(game.profile.run.floor_number, 2)
	assert_eq(_saved(game).run.floor_number, 2, "saved between floors")
	assert_eq(_saved(game).heroes[0].xp, xp)
	_press(game.screen, "NextButton")
	assert_eq(_battle(game).battle_title, "Floor 2")
	after_each_clean()

func test_heroes_start_the_next_floor_with_their_carried_hp() -> void:
	var game := _game()
	game.start_tower(1)
	_finish(game, true)
	game.profile.run.hero_hp[0] = 20
	game.next_step()
	assert_eq(_battle(game).battle.state.units[0].hp, 20)
	after_each_clean()

func test_a_lost_floor_ends_the_run() -> void:
	var game := _game()
	game.start_tower(1)
	_finish(game, false)
	assert_true(game.screen is RunScreen)
	assert_eq(game.profile.run, null)
	assert_eq(game.profile.heroes[0].xp, 0)
	assert_eq(_saved(game).run, null)
	_press(game.screen, "BackButton")
	assert_true(game.screen is PartyScreen)
	assert_true((game.screen.get_node("%Summary") as Label).text.begins_with("Defeat"))
	after_each_clean()

func test_a_saved_run_resumes_at_the_next_floor() -> void:
	var game := _game()
	game.start_tower(1)
	_finish(game, true)
	game.free()
	var reopened := _open()
	assert_true(reopened.screen is PartyScreen)
	assert_eq(reopened.screen.find_child("TowerButton", true, false), null, "no new run while one is saved")
	_press(reopened.screen, "ContinueButton")
	assert_eq(_battle(reopened).battle_title, "Floor 2")
	after_each_clean()

func test_a_run_can_be_abandoned() -> void:
	var game := _game()
	game.start_tower(1)
	_finish(game, true)
	game.show_party()
	_press(game.screen, "AbandonButton")
	assert_eq(game.profile.run, null)
	assert_eq(_saved(game).run, null)
	assert_true(game.screen.find_child("TowerButton", true, false) != null)
	after_each_clean()

func test_a_boss_gives_a_boon_then_the_climb_goes_on() -> void:
	var game := _game()
	game.profile.cleared_stages.append(game.tower.stages[0])  # The cap goes up to floor 20.
	game.start_tower(1)
	game.profile.run.floor_number = 10
	game.next_step()
	_finish(game, true)
	assert_true(game.profile.run.awaiting_choice())
	var go_on := game.screen.find_child("ContinueButton", true, false) as Button
	assert_true(go_on.disabled, "a choice comes first")
	_press(game.screen, "Boon0")
	assert_false(go_on.disabled)
	var boon := game.profile.run.boss_offer[0]
	go_on.pressed.emit()
	assert_eq(game.profile.run.boons, [boon] as Array[BoonData])
	assert_eq(_battle(game).battle_title, "Floor 11")
	assert_eq(_saved(game).run.boons.size(), 1)
	after_each_clean()

func test_a_pending_boss_choice_survives_a_restart_and_leaving_ends_the_run() -> void:
	var game := _game()
	game.profile.cleared_stages.append(game.tower.stages[0])
	game.start_tower(1)
	game.profile.run.floor_number = 10
	game.next_step()
	_finish(game, true)
	game.free()
	var reopened := _open()
	_press(reopened.screen, "ContinueButton")
	assert_true(reopened.screen is RunScreen, "back to the boss choice")
	_press(reopened.screen, "Heal")
	_press(reopened.screen, "LeaveButton")
	assert_eq(reopened.profile.run, null)
	assert_true(_lines(reopened).contains("leave the tower after floor 10"), _lines(reopened))
	_press(reopened.screen, "BackButton")
	assert_true(reopened.screen is PartyScreen)
	assert_eq(reopened.profile.best_depth, 10)
	after_each_clean()

func test_a_cleared_stage_unlocks_the_next_one() -> void:
	var game := _game()
	_press(game.screen, "Stage0")
	assert_eq(_battle(game).battle_title, game.tower.stages[0].display_name)
	_finish(game, true)
	assert_eq(game.profile.run, null, "a stage is one battle")
	assert_eq(game.profile.cleared_stages, [game.tower.stages[0]] as Array[StageData])
	_press(game.screen, "BackButton")
	assert_false((game.screen.find_child("Stage1", true, false) as Button).disabled)
	var floors := game.screen.find_child("StartFloor", true, false) as OptionButton
	assert_eq(floors.item_count, 2, "floors 1 and 11")
	after_each_clean()

func test_a_locked_stage_cant_be_started() -> void:
	var game := _game()
	game.start_stage(1)
	assert_true(game.screen is PartyScreen)
	assert_eq(game.profile.run, null)
	assert_true((game.screen.get_node("%Summary") as Label).text.contains("previous stage"))
	after_each_clean()

func test_results_are_saved_as_soon_as_the_battle_ends() -> void:
	var game := _game()
	game.start_tower(1)
	var battle := _battle(game)
	assert_eq(battle.input_state, BattleController.State.PLACING, "a floor opens on placement")
	battle.end_turn()  # Ready.
	for unit in battle.battle.state.units:
		if unit.team == UnitState.Team.ENEMY:
			unit.hp = 0
	battle._begin_next()  # The battle notices it's over and shows the result screen.
	assert_eq(battle.input_state, BattleController.State.ENDED)
	var xp := game.profile.heroes[0].xp
	assert_true(xp > 0, "applied before Continue")
	assert_eq(_saved(game).heroes[0].xp, xp, "already saved")
	battle.battle_finished.emit(battle.battle.state)
	assert_eq(game.profile.heroes[0].xp, xp, "not rewarded twice")
	assert_eq(game.profile.run.floor_number, 2, "not advanced twice")
	after_each_clean()

func test_equip_requests_go_through_the_game_and_save() -> void:
	var game := _game()
	game.profile.stash = [load("res://data/runes/might.tres")] as Array[RuneData]
	var party := game.screen as PartyScreen
	party.equip_requested.emit(0, 0)
	assert_eq(game.profile.heroes[0].runes[0].display_name, "Rune of Might")
	assert_eq(_saved(game).heroes[0].runes[0].display_name, "Rune of Might")
	party.unequip_requested.emit(0, 0)
	assert_eq(game.profile.stash.size(), 1)
	party.unequip_requested.emit(0, 0)
	assert_true((party.get_node("%Summary") as Label).text.contains("empty"), "errors are shown")
	assert_true(party.find_child("TowerButton", true, false) != null, "the hub stays")
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


func test_an_invalid_tower_keeps_the_hub_with_its_errors() -> void:
	var game := _game()
	game.tower = TowerConfig.new()
	game.start_tower(1)
	assert_true(game.screen is PartyScreen)
	assert_true((game.screen.get_node("%Summary") as Label).text.contains("The tower is invalid"))
	assert_eq(game.profile.run, null)
	after_each_clean()
