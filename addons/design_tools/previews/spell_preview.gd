@tool
class_name SpellPreview
extends RefCounted
## What a spell does, computed for the editor preview (and tests): its range and area on an
## empty grid, expected damage / heals at several Power and resistance values, AP efficiency
## and the expected value of the statuses it applies. Uses the battle rules themselves.

const POWER_STEPS: Array[int] = [0, 20, 50]
const RESISTANCE_STEPS: Array[int] = [0, 25, 50]


## Range and area around a caster at the grid center, on an empty flat grid.
class Grid2D:
	var size := 0
	var caster := Vector2i.ZERO
	var target := Vector2i.ZERO  ## A sample target: the farthest in-range cell along +x.
	var in_range: Array[Vector2i] = []
	var area: Array[Vector2i] = []


static func grid(spell: SpellData) -> Grid2D:
	var result := Grid2D.new()
	var reach := spell.max_range + (spell.area.size if spell.area != null else 0) + 1
	result.size = reach * 2 + 1
	result.caster = Vector2i(reach, reach)
	var cells := result.size * result.size
	var heights := PackedInt32Array()
	heights.resize(cells)
	var types := PackedByteArray()
	types.resize(cells)
	var flat := Grid.new(Vector2i(result.size, result.size), heights, types)
	for y in result.size:
		for x in result.size:
			var distance := Targeting.distance(result.caster, Vector2i(x, y))
			if distance >= spell.min_range and distance <= spell.max_range:
				result.in_range.append(Vector2i(x, y))
	result.target = result.caster + Vector2i(spell.max_range, 0)
	if spell.area != null:
		result.area = Targeting.area_cells(flat, spell.area, result.caster, result.target)
	return result


## Expected damage (negative for heals) of all the spell's damage / heal effects on one
## target, at `power` and `resistance` (%, for every damage type).
static func expected_amount(spell: SpellData, power: int, resistance: int) -> float:
	var total := 0.0
	for effect in spell.effects:
		if effect is DamageEffect:
			var damage := effect as DamageEffect
			var resisted := resistance if damage.damage_type != null else 0
			total += damage.average_roll() * damage.power_multiplier(power) * (100.0 - mini(resisted, UnitState.MAX_RESISTANCE_PERCENT)) / 100.0
		elif effect is HealEffect:
			var heal := effect as HealEffect
			total -= heal.average_roll() * maxf(0.0, 100.0 + power * heal.power_scaling / 100.0) / 100.0
	return total


## Expected damage (or heal) over a status's whole duration from its ticks, at Power 0.
static func status_tick_total(status: StatusData) -> float:
	var total := 0.0
	for effect in status.tick_effects:
		if effect is DamageEffect:
			total += (effect as DamageEffect).average_roll() * status.duration
		elif effect is HealEffect:
			total -= (effect as HealEffect).average_roll() * status.duration
	return total


## Text lines for the preview panel.
static func summary(spell: SpellData) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("%s — %d AP, range %s%s" % [spell.display_name, spell.ap_cost,
			EffectData.amount_text(spell.min_range, spell.max_range), ", line of sight" if spell.needs_line_of_sight else ""])
	var base := expected_amount(spell, 0, 0)
	if not is_zero_approx(base):
		var word := "damage" if base > 0.0 else "heal"
		lines.append("Expected %s per target (Power across, resistance down):" % word)
		var header := "        " + "  ".join(POWER_STEPS.map(func(p: int) -> String: return "P%+4d" % p))
		lines.append(header)
		for resistance in RESISTANCE_STEPS:
			var row := "R%3d%%  " % resistance
			for power in POWER_STEPS:
				row += "  %5.1f" % absf(expected_amount(spell, power, resistance))
			lines.append(row)
		if spell.ap_cost > 0:
			lines.append("Per AP: %.1f %s (Power 0)" % [absf(base) / spell.ap_cost, word])
	for effect in spell.effects:
		if effect is ApplyStatusEffect and (effect as ApplyStatusEffect).status != null:
			var status := (effect as ApplyStatusEffect).status
			var ticks := status_tick_total(status)
			var tick_text := ""
			if not is_zero_approx(ticks):
				tick_text = ", %.1f %s in total" % [absf(ticks), "damage" if ticks > 0.0 else "heal"]
			lines.append("Status: %s for %d turns (%s)%s" % [status.display_name, status.duration, status.describe(), tick_text])
	return lines
