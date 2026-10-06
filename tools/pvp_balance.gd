extends SceneTree
## Balance check for the PvP classes: AI-vs-AI matches on the real rules and maps (see PvpSimulator).
##   godot --headless --script res://tools/pvp_balance.gd -- duel games=6
##   godot --headless --script res://tools/pvp_balance.gd -- teams2 games=60
##   godot --headless --script res://tools/pvp_balance.gd -- teams4 games=60 map=ruins size=14
## Modes: duel (every class against every class, 1v1: a win-rate matrix), teams2 / teams3 / teams4 (random teams of
## that size, duplicates allowed: each class's win rate in the matches it was in). Options: games= (per pair for
## duel, in total for teams), seed=, map= (a typology file name), size=. The AI plays worse than a player does and
## knows no class tricks (it never holds a stealth for an ambush on purpose), so read it as a lower bound and look for
## classes that are far from the others: a win rate between 40 % and 60 % in teams, and a matrix without a class
## that loses to (or beats) nearly everything.

var _games := 6
var _seed := 1
var _map := "open_field"
var _size := 12


func _init() -> void:
	var mode := "duel"
	for arg in OS.get_cmdline_user_args():
		if "=" in arg:
			var parts := arg.split("=")
			match parts[0]:
				"games": _games = int(parts[1])
				"seed": _seed = int(parts[1])
				"map": _map = parts[1]
				"size": _size = int(parts[1])
		else:
			mode = arg
	var started := Time.get_ticks_msec()
	if mode == "duel":
		_duel()
	elif mode.begins_with("teams"):
		_teams(int(mode.trim_prefix("teams")))
	else:
		print("unknown mode %s (duel, teams2, teams3, teams4)" % mode)
	print("(%d s)" % ((Time.get_ticks_msec() - started) / 1000))
	quit()


func _names() -> Array[String]:
	var names: Array[String] = []
	for index in PvpHeroes.hero_count():
		names.append(PvpHeroes.hero(index).display_name())
	return names


func _duel() -> void:
	var count := PvpHeroes.hero_count()
	var names := _names()
	var wins: Array = []  # wins[i][j]: games class i won against class j (of _games).
	for i in count:
		wins.append([])
		for j in count:
			wins[i].append(0.0)
	var rounds := 0.0
	var played := 0
	for i in count:
		for j in range(i + 1, count):
			for game in _games:
				var map_seed := _seed * 1000 + i * 100 + j * 10 + game
				var i_first := game % 2 == 0  # Sides swap, so neither class always gets the same start zone.
				var side_a: Array[int] = [i if i_first else j]
				var side_b: Array[int] = [j if i_first else i]
				var result := PvpSimulator.play(side_a, side_b, map_seed, _size, _map)
				rounds += result.rounds
				played += 1
				var i_won := result.winner == (0 if i_first else 1)
				var j_won := result.winner == (1 if i_first else 0)
				if i_won:
					wins[i][j] += 1.0
				elif j_won:
					wins[j][i] += 1.0
				else:
					wins[i][j] += 0.5  # A draw splits.
					wins[j][i] += 0.5
	print("1v1, %d games per pair on %s %dx%d. Row class's win rate against the column class (%%):" % [_games, _map, _size, _size])
	var header := "%-12s" % ""
	for j in count:
		header += "%6s" % names[j].left(5)
	header += "   avg"
	print(header)
	for i in count:
		var line := "%-12s" % names[i]
		var total := 0.0
		for j in count:
			if i == j:
				line += "%6s" % "-"
			else:
				var rate: float = 100.0 * float(wins[i][j]) / _games
				total += rate
				line += "%6d" % roundi(rate)
		line += "%6d" % roundi(total / (count - 1))
		print(line)
	print("average match length: %.1f rounds" % (rounds / maxi(1, played)))


func _teams(size: int) -> void:
	var count := PvpHeroes.hero_count()
	var names := _names()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var present := PackedFloat64Array()
	var won := PackedFloat64Array()
	present.resize(count)
	won.resize(count)
	var rounds := 0.0
	var draws := 0
	var a_wins := 0
	for game in _games:
		var side_a: Array[int] = []
		var side_b: Array[int] = []
		for slot in size:
			side_a.append(rng.randi_range(0, count - 1))
			side_b.append(rng.randi_range(0, count - 1))
		var result := PvpSimulator.play(side_a, side_b, _seed * 1000 + game, _size + (size - 1), _map)
		rounds += result.rounds
		if result.winner == 0:
			a_wins += 1
		elif result.winner == -1:
			draws += 1
		for hero in side_a:
			present[hero] += 1.0
			won[hero] += 1.0 if result.winner == 0 else (0.5 if result.winner == -1 else 0.0)
		for hero in side_b:
			present[hero] += 1.0
			won[hero] += 1.0 if result.winner == 1 else (0.5 if result.winner == -1 else 0.0)
	print("%dv%d, %d random games on %s: side A won %d, side B won %d, %d draws; %.1f rounds on average" % [
			size, size, _games, _map, a_wins, _games - a_wins - draws, draws, rounds / _games])
	print("%-12s %8s %8s" % ["class", "games", "win %"])
	for hero in count:
		print("%-12s %8d %8d" % [names[hero], int(present[hero]), roundi(100.0 * won[hero] / maxf(1.0, present[hero]))])
