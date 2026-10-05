@tool
class_name CompositionSlot
extends Resource
## One place in a team: a fixed enemy, or (with none) any enemy of the band with this role.

@export var role := EnemyData.Role.BRUISER
## Overrides the role: this enemy exactly (e.g. two Wargs for a pack).
@export var enemy: EnemyData
## Levels above (or below) the floor's enemy level.
@export_range(-10, 10) var level_offset := 0


func describe() -> String:
	return enemy.display_name() if enemy != null else EnemyData.Role.keys()[role].capitalize()
