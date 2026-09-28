class_name BattleFixtures
extends RefCounted
## Builders for small battles in tests.


static func unit(unit_name: String, initiative := 100, mp := 3, ap := 6, max_hp := 20) -> UnitData:
	var data := UnitData.new()
	data.display_name = unit_name
	data.initiative = initiative
	data.mp = mp
	data.ap = ap
	data.max_hp = max_hp
	return data


## A spell dealing exactly `damage` (min = max, so tests are deterministic).
static func damage_spell(ap_cost := 3, min_range := 1, max_range := 1, damage := 5,
		area_kind := AreaShape.Kind.SINGLE, area_size := 0, needs_los := false) -> SpellData:
	var spell := SpellData.new()
	spell.display_name = "Hit"
	spell.ap_cost = ap_cost
	spell.min_range = min_range
	spell.max_range = max_range
	spell.needs_line_of_sight = needs_los
	spell.area = AreaShape.new()
	spell.area.kind = area_kind
	spell.area.size = area_size
	var effect := DamageEffect.new()
	effect.min_amount = damage
	effect.max_amount = damage
	spell.effects = [effect] as Array[EffectData]
	return spell


## A battle with explicit teams, placed on the layout's spawns in order.
static func state_with(layout: String, players: Array[UnitData], enemies: Array[UnitData], rng_seed := 1) -> BattleState:
	var map := MapData.new()
	map.layout = layout
	return BattleState.create(map.parse(), players, enemies, rng_seed)


## A battle on `layout` (MapData format) with one unit per spawn, in spawn order.
## Players act first (higher initiative), in spawn order.
static func state(layout: String, mp := 3, rng_seed := 1) -> BattleState:
	var map := MapData.new()
	map.layout = layout
	var parsed := map.parse()
	if not parsed.errors.is_empty():
		push_error("BattleFixtures: %s" % [parsed.errors])
		return null
	var players: Array[UnitData] = []
	for i in parsed.player_spawns.size():
		players.append(unit("P%d" % i, 200 - i, mp))
	var enemies: Array[UnitData] = []
	for i in parsed.enemy_spawns.size():
		enemies.append(unit("E%d" % i, 100 - i, mp))
	return BattleState.create(parsed, players, enemies, rng_seed)


static func modifier(stat: StatModifier.Stat, amount: int) -> StatModifier:
	var result := StatModifier.new()
	result.stat = stat
	result.amount = amount
	return result


## A status with an optional fixed damage (> 0) or heal (< 0) per tick, and modifiers.
static func status(status_name: String, duration := 2, tick_amount := 0,
		modifiers: Array[StatModifier] = [], is_positive := false) -> StatusData:
	var result := StatusData.new()
	result.display_name = status_name
	result.short_label = status_name.left(1)
	result.duration = duration
	result.is_positive = is_positive
	if tick_amount > 0:
		var damage := DamageEffect.new()
		damage.min_amount = tick_amount
		damage.max_amount = tick_amount
		result.tick_effects = [damage] as Array[EffectData]
	elif tick_amount < 0:
		var heal := HealEffect.new()
		heal.min_amount = -tick_amount
		heal.max_amount = -tick_amount
		result.tick_effects = [heal] as Array[EffectData]
	result.modifiers = modifiers
	return result


static func apply_status(applied: StatusData, filter := EffectData.TargetFilter.ALL) -> ApplyStatusEffect:
	var effect := ApplyStatusEffect.new()
	effect.status = applied
	effect.target_filter = filter
	return effect


## A spell whose only effects are the given ones (no damage), 3 AP, range 0-3, no sight.
static func effect_spell(effects: Array[EffectData], ap_cost := 3, min_range := 0, max_range := 3,
		area_kind := AreaShape.Kind.SINGLE, area_size := 0) -> SpellData:
	var spell := damage_spell(ap_cost, min_range, max_range, 0, area_kind, area_size)
	spell.display_name = "Effect"
	spell.effects = effects
	return spell


static func rune(rune_name: String, rarity := RuneData.Rarity.COMMON, modifiers: Array[StatModifier] = []) -> RuneData:
	var result := RuneData.new()
	result.display_name = rune_name
	result.rarity = rarity
	result.modifiers = modifiers if not modifiers.is_empty() else ([modifier(StatModifier.Stat.POWER, 5)] as Array[StatModifier])
	return result
