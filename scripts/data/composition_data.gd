@tool
class_name CompositionData
extends Resource
## A team that makes tactical sense (a Mushroom Sage behind an Orc Guard, a Warg pack…): its
## slots, in order, set who spawns and how many. Floor bands list the compositions they draw
## from (FloorBand.compositions, boss_compositions). On an elite floor the first slot is the
## elite; in a boss composition the first slot is the boss (drawn from the band's boss pool).

## A name for designers (not shown to players, not translated).
@export var label := ""
@export var slots: Array[CompositionSlot] = []
## How likely the band draws it, against the band's other compositions.
@export_range(1, 100) var weight := 1


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if slots.is_empty():
		errors.append("composition %s has no slots" % label)
	if slots.size() > MapGenerator.MAX_ENEMIES:
		errors.append("composition %s: %d slots (maps hold at most %d enemies)" % [label, slots.size(), MapGenerator.MAX_ENEMIES])
	if weight < 1:
		errors.append("composition %s: weight below 1" % label)
	var fixed: Dictionary[EnemyData, int] = {}
	for slot in slots:
		if slot == null:
			errors.append("composition %s: empty slot" % label)
		elif slot.enemy == null and slot.role == EnemyData.Role.NONE:
			errors.append("composition %s: a slot needs a role or an enemy" % label)
		elif slot.enemy != null:
			fixed[slot.enemy] = fixed.get(slot.enemy, 0) + 1
	for enemy in fixed:
		if enemy.max_per_floor > 0 and fixed[enemy] > enemy.max_per_floor:
			errors.append("composition %s: %d × %s (at most %d per floor)" % [label, fixed[enemy], enemy.display_name(), enemy.max_per_floor])
	return errors
