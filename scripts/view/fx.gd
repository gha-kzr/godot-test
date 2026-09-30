class_name Fx
extends Node3D
## A one-shot visual effect (a particle burst). Put it at a unit and it plays by itself, then
## frees itself after `duration`. Effects are scenes with this script on the root and
## CPUParticles3D children (they work in the web build's Compatibility renderer); a new one is
## a scene, referenced from data (DamageType, SpellData, BattleFx).

@export var duration := 1.0


## Multiplies the particles' colors by `color` (a status's color, say); call before adding it.
func set_tint(color: Color) -> void:
	for particles in find_children("*", "CPUParticles3D", true, false):
		(particles as CPUParticles3D).color = color


func _ready() -> void:
	for particles in find_children("*", "CPUParticles3D", true, false):
		(particles as CPUParticles3D).restart()
		(particles as CPUParticles3D).emitting = true
	create_tween().tween_interval(duration).finished.connect(queue_free)  # A tween pauses with the tree, like the particles.
