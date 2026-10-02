@tool
class_name Achievements
extends RefCounted
## Unlocking achievements: after a won battle, a rune change or a level, check every locked one
## against the profile (and what the battle just was) and record the newly met ones in the
## profile. Pure rules; the Game root shows the toast.

const DIRECTORY := "res://data/achievements"

static var _all: Array[AchievementData] = []


## What the battle that just ended was (all false when the check isn't about a battle).
class Context:
	var elite := false
	var boss := false
	var flawless := false

	## A won battle: its floor's kind (a stage counts as a boss fight) and whether every hero lived.
	static func from_battle(state: BattleState, floor_number: int, is_stage: bool) -> Context:
		var context := Context.new()
		context.elite = not is_stage and TowerConfig.is_elite_floor(floor_number) and not TowerConfig.is_boss_floor(floor_number)
		context.boss = is_stage or TowerConfig.is_boss_floor(floor_number)
		context.flawless = state.units.all(func(unit: UnitState) -> bool: return unit.team != UnitState.Team.PLAYER or unit.is_alive())
		return context


## Every achievement of the game (the files in DIRECTORY), in display order.
static func all() -> Array[AchievementData]:
	if _all.is_empty():
		for file in ResourceLoader.list_directory(DIRECTORY):
			if file.ends_with(".tres"):
				var achievement := load(DIRECTORY.path_join(file)) as AchievementData
				if achievement != null:
					_all.append(achievement)
		_all.sort_custom(func(a: AchievementData, b: AchievementData) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else a.id() < b.id())
	return _all


## Records (and returns) the achievements the profile now meets and didn't have.
static func check(profile: Profile, context: Context = null) -> Array[AchievementData]:
	var unlocked: Array[AchievementData] = []
	var ctx := context if context != null else Context.new()
	for achievement in all():
		if achievement.id() in profile.achievements:
			continue
		if _met(achievement, profile, ctx):
			profile.achievements.append(achievement.id())
			unlocked.append(achievement)
	return unlocked


static func _met(achievement: AchievementData, profile: Profile, context: Context) -> bool:
	match achievement.kind:
		AchievementData.Kind.FLOOR_REACHED: return profile.best_depth >= achievement.threshold
		AchievementData.Kind.ELITE_DEFEATED: return context.elite
		AchievementData.Kind.BOSS_DEFEATED: return context.boss
		AchievementData.Kind.FLAWLESS_FLOOR: return context.flawless
		AchievementData.Kind.FULL_RUNES:
			return profile.heroes.any(func(record: HeroRecord) -> bool: return record.runes.all(func(rune: RuneData) -> bool: return rune != null))
		AchievementData.Kind.HERO_LEVEL:
			return profile.heroes.any(func(record: HeroRecord) -> bool: return record.level >= achievement.threshold)
		AchievementData.Kind.STAGES_CLEARED: return profile.cleared_stages.size() >= achievement.threshold
	return false
