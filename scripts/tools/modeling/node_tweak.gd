class_name NodeTweak
extends Resource
## One hand-made adjustment of a model's node, kept in the model's tweaks file: a part's look
## and placement, or a joint's rest pose. Stored as *changes* to what the recipe builds (a move,
## a turn, a scale factor), so a recipe edit that moves the node still carries the tweak with it.
## Zero / one / unset values mean "no change".

## The node's name path under the model root, node names (`Rig/Hips/Head/Helmet`, `Rig/Hips/Arm_L`).
@export var path := ""
## Added to the node's position (meters).
@export var position_offset := Vector3.ZERO
## Added to the node's rotation (degrees).
@export var rotation_offset := Vector3.ZERO
## Multiplies the node's scale.
@export var scale_factor := Vector3.ONE
## A part's color, as it should look on screen (see ModelKit.ALBEDO_FACTOR); used when `recolor`.
@export var recolor := false
@export var color := Color.WHITE
## A part's emissive strength when >= 0 (-1: as the recipe built it).
@export var emissive := -1.0
@export var hidden := false


## Whether the tweak changes nothing (the workshop drops it from the file).
func is_empty() -> bool:
	return position_offset == Vector3.ZERO and rotation_offset == Vector3.ZERO and scale_factor == Vector3.ONE \
			and not recolor and emissive < 0.0 and not hidden


func apply_to(node: Node3D, kit: ModelKit) -> void:
	node.position += position_offset
	node.rotation_degrees += rotation_offset
	node.scale *= scale_factor
	if hidden:
		node.visible = false
	var part := node as MeshInstance3D
	if part != null and (recolor or emissive >= 0.0):
		var look := kit.look_of(part)
		var new_color := color if recolor else look["color"] as Color
		var new_emissive := emissive if emissive >= 0.0 else look["emissive"] as float
		part.material_override = kit.material(new_color, new_emissive)
		kit.set_look(part, new_color, new_emissive)
