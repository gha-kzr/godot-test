@tool
class_name SpellData
extends Resource

@export var display_name := ""
## Shown on the spell bar and cards (a white icon, tinted); a default one when empty.
@export var icon: Texture2D
## The animation the caster plays: a logical name from UnitModel ("Attack", "Cast", "Hit"…);
## empty picks Attack for a melee spell (range 1) and Cast otherwise.
@export var cast_animation: StringName
## Effect spawned on the caster when the spell is cast, and effect spawned on each unit it
## damages instead of the damage type's own (both optional, empty for now: per-spell effects
## are just a scene and these fields).
@export var cast_effect: PackedScene
@export var impact_effect: PackedScene
## The sound event played at the cast (an AudioSet.SFX_EVENTS name). Empty: its damage type's,
## else the generic `cast`.
@export var cast_sound: StringName = &""
@export_group("Cast timing")
## A model file (an imported .fbx / .glb) whose animation the caster borrows for this spell. Its
## skeleton must carry the same bones as the caster's (the Quaternius characters share one
## rig); a file that doesn't fit is reported and the caster's own animation plays instead.
## Empty: the caster's own animation (`cast_animation`).
@export var animation_scene: PackedScene
## Which animation of `animation_scene` (the part after a "|" counts: "SwordSlash" finds
## "CharacterArmature|SwordSlash"); empty takes its first one.
@export var animation_name := ""
## The part of the animation that plays, in seconds: from `animation_start` to `animation_end`
## (0: to its end), at `animation_speed`. Cuts a long clip down to the swing.
@export_range(0.0, 10.0, 0.01, "suffix:s") var animation_start := 0.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var animation_end := 0.0
@export_range(0.1, 4.0, 0.05) var animation_speed := 1.0
## Seconds from the start of the cast until its effects land (or, with a projectile, until it
## leaves the caster). -1: the default pacing (the caster's lunge, then a short flash of the area).
@export_range(-1.0, 3.0, 0.01, "suffix:s") var impact_delay := -1.0
## Flown from the caster to the target cell before the effects land (any Node3D scene, with
## particles for instance; not an Fx scene, which frees itself on a timer).
@export var projectile: PackedScene
## World units per second.
@export_range(1.0, 60.0, 0.5, "suffix:u/s") var projectile_speed := 14.0
## The projectile falls from the sky onto the target cell (a meteor) instead of flying from the
## caster.
@export var projectile_falls := false
## How many projectiles are sent, one after the other `projectile_interval` seconds apart (a
## volley of arrows). With several, they aim at the cells of the area in turn, so they spread
## over it; the effects land when the last one arrives.
@export_range(1, 24) var projectile_count := 1
@export_range(0.0, 1.0, 0.01, "suffix:s") var projectile_interval := 0.06
## Camera shake when the effects land (a heavy impact); 0: none. In world units, 0.1 is felt.
@export_range(0.0, 0.5, 0.01) var impact_shake := 0.0
@export_group("")
@export_range(0, 12) var ap_cost := 3
## Turns the caster waits before casting it again: 0 none, 1 once per turn, 2 every other
## turn, and so on (counted at the caster's turn starts).
@export_range(0, 9) var cooldown := 0
## Manhattan distance from the caster. 0 allows targeting the caster's own cell.
@export_range(0, 20) var min_range := 1
@export_range(0, 20) var max_range := 1
@export var needs_line_of_sight := true
## Whether standing higher than the target extends max_range (formula in the targeting rules).
@export var height_extends_range := false
@export var area: AreaShape
@export var effects: Array[EffectData] = []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("spell has no display_name")
	if min_range > max_range:
		errors.append("%s: min_range (%d) > max_range (%d)" % [display_name, min_range, max_range])
	if area == null:
		errors.append("%s: no area" % display_name)
	else:
		for error in area.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	if animation_start < 0.0 or (animation_end > 0.0 and animation_end <= animation_start):
		errors.append("%s: animation_end (%s) must be 0 or after animation_start (%s)" % [display_name, animation_end, animation_start])
	if animation_speed <= 0.0:
		errors.append("%s: animation_speed must be above 0" % display_name)
	if impact_delay < 0.0 and not is_equal_approx(impact_delay, -1.0):
		errors.append("%s: impact_delay must be -1 (default) or 0 and more" % display_name)
	if projectile != null and projectile_speed <= 0.0:
		errors.append("%s: projectile_speed must be above 0" % display_name)
	if not cast_sound.is_empty() and cast_sound not in AudioSet.SFX_EVENTS:
		errors.append("%s: unknown cast_sound %s" % [display_name, cast_sound])
	if projectile_count > 1 and projectile == null:
		errors.append("%s: projectile_count above 1 needs a projectile" % display_name)
	if effects.is_empty():
		errors.append("%s: no effects" % display_name)
	for effect in effects:
		if effect == null:
			errors.append("%s: empty effect slot" % display_name)
			continue
		for error in effect.get_validation_errors():
			errors.append("%s: %s" % [display_name, error])
	return errors


## The sound event of casting this spell: its own, else the first damage effect's type, else `cast`.
func cast_sound_event() -> StringName:
	if not cast_sound.is_empty():
		return cast_sound
	for effect in effects:
		if effect is DamageEffect and (effect as DamageEffect).damage_type != null:
			var type_sound := (effect as DamageEffect).damage_type.cast_sound
			if not type_sound.is_empty():
				return type_sound
	return &"cast"


## The icon to show: its own, else the default spell icon.
func display_icon() -> Texture2D:
	return icon if icon != null else load("res://ui/icons/spell_default.svg") as Texture2D
