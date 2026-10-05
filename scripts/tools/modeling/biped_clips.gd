class_name BipedClips
extends RefCounted
## The animation set of a two-legged model: Idle, Walk, Attack, Cast, Hit, Death, Victory,
## Defeat, and Shoot (a bow drawn and released: the left arm aims, the right one pulls back; for
## arrow spells, `cast_animation = &"Shoot"`; a model without it plays Cast). The model needs the joints Rig (the whole body, at the feet), Hips (the upper body,
## at the waist), Head, Arm.L, Arm.R, Leg.L, Leg.R. It faces +Z, so its right side is -X: an
## arm swings forward with a negative X rotation and out to its side with a negative (right) /
## positive (left) Z rotation.
## Options: `attack` (&"swing": a sword overhead then down, &"punch": a jab, &"shoot": a bow
## drawn and released), `stride` (leg swing in degrees), `bob` (meters), `lie` (half the body's
## depth, how far the dead body is lifted so it lies on the floor).


static func animate(kit: ModelKit, options := {}) -> AnimationPlayer:
	var attack: StringName = options.get("attack", &"swing")
	var stride: float = options.get("stride", 30.0)
	var bob: float = options.get("bob", 0.05)
	var lie: float = options.get("lie", 0.15)
	var a := RigAnimator.new(kit)
	var up := Vector3(0, bob * 0.4, 0)
	# Idle: a breath.
	a.clip("Idle", 1.6, [
		[0.0, {}],
		[0.8, {"Rig:p": up, "Head": _x(-2), "Hips": _x(1.5), "Arm.R": _z(-3), "Arm.L": _z(3)}],
		[1.6, {}],
	], true)
	# Walk: legs and arms swing in opposition, the body bobs twice per cycle.
	var hop := Vector3(0, bob, 0)
	a.clip("Walk", 0.6, [
		[0.0, {"Leg.L": _x(-stride), "Leg.R": _x(stride), "Arm.L": _x(stride * 0.8), "Arm.R": _x(-stride * 0.8), "Hips": Vector3(5, 0, 3)}],
		[0.15, {"Rig:p": hop, "Leg.L": _x(-stride * 0.1), "Leg.R": _x(stride * 0.1), "Hips": Vector3(5, 0, 0)}],
		[0.3, {"Leg.L": _x(stride), "Leg.R": _x(-stride), "Arm.L": _x(-stride * 0.8), "Arm.R": _x(stride * 0.8), "Hips": Vector3(5, 0, -3)}],
		[0.45, {"Rig:p": hop, "Leg.L": _x(stride * 0.1), "Leg.R": _x(-stride * 0.1), "Hips": Vector3(5, 0, 0)}],
		[0.6, {"Leg.L": _x(-stride), "Leg.R": _x(stride), "Arm.L": _x(stride * 0.8), "Arm.R": _x(-stride * 0.8), "Hips": Vector3(5, 0, 3)}],
	], true)
	a.clip("Attack", 0.7, _attack_poses(attack))
	# Cast: both arms rise, a tremor, then a thrust forward.
	a.clip("Cast", 0.9, [
		[0.25, {"Arm.L": Vector3(-150, 0, 15), "Arm.R": Vector3(-150, 0, -15), "Head": _x(-12), "Hips": _x(-8), "Rig:p": Vector3(0, 0.08, 0)}, RigAnimator.SETTLE],
		[0.4, {"Arm.L": Vector3(-160, 0, 20), "Arm.R": Vector3(-160, 0, -20), "Head": _x(-14), "Hips": _x(-10), "Rig:p": Vector3(0, 0.1, 0)}],
		[0.55, {"Arm.L": Vector3(-150, 0, 15), "Arm.R": Vector3(-150, 0, -15), "Head": _x(-12), "Hips": _x(-8), "Rig:p": Vector3(0, 0.08, 0)}],
		[0.68, {"Arm.L": Vector3(-85, 0, 5), "Arm.R": Vector3(-85, 0, -5), "Head": _x(8), "Hips": _x(14), "Rig:p": Vector3(0, 0, 0.12)}, RigAnimator.SNAP],
	])
	# Shoot: the left arm aims, the right hand pulls the string back, a quick release at 0.34 s.
	a.clip("Shoot", 0.7, [
		[0.1, {"Arm.L": _x(-90), "Arm.R": Vector3(-90, 0, -20), "Hips": _x(-3)}, RigAnimator.SETTLE],
		[0.26, {"Arm.L": _x(-92), "Arm.R": Vector3(40, 0, -65), "Hips": _x(-4), "Head": _x(-3)}],
		[0.32, {"Arm.L": _x(-92), "Arm.R": Vector3(42, 0, -66), "Hips": _x(-4), "Head": _x(-3)}],
		[0.37, {"Arm.L": _x(-95), "Arm.R": Vector3(-70, 0, -30), "Hips": _x(-2), "Rig:p": Vector3(0, 0, -0.05)}, RigAnimator.SNAP],
		[0.5, {"Arm.L": _x(-95), "Arm.R": Vector3(-60, 0, -25), "Rig:p": Vector3(0, 0, -0.04)}, RigAnimator.SETTLE],
	])
	# Hit: thrown back, head snapped, arms flung out.
	a.clip("Hit", 0.4, [
		[0.08, {"Rig": _x(-12), "Rig:p": Vector3(0, 0, -0.12), "Head": _x(-22), "Arm.L": Vector3(20, 0, 25), "Arm.R": Vector3(20, 0, -25)}, RigAnimator.SETTLE],
	])
	# Death: falls onto its back; the clip ends there.
	a.clip("Death", 0.5, [
		[0.12, {"Hips": _x(-12), "Head": _x(-15), "Rig:p": Vector3(0, 0.04, -0.06), "Arm.L": _z(30), "Arm.R": _z(-30)}, RigAnimator.SETTLE],
		[0.5, {"Rig": _x(-90), "Rig:p": Vector3(0, lie, -0.1), "Arm.L": _z(55), "Arm.R": _z(-55), "Leg.L": _z(8), "Leg.R": _z(-8)}, RigAnimator.SNAP],
	], false, true)
	# Victory: a crouch, then two hops with the arms up.
	a.clip("Victory", 1.0, [
		[0.12, {"Rig:p": Vector3(0, -0.06, 0), "Arm.L": _x(25), "Arm.R": _x(25)}, RigAnimator.SETTLE],
		[0.3, {"Rig:p": Vector3(0, 0.28, 0), "Arm.L": Vector3(-165, 0, 15), "Arm.R": Vector3(-165, 0, -15), "Head": _x(-10)}, RigAnimator.SETTLE],
		[0.5, {"Rig:p": Vector3(0, 0, 0), "Arm.L": Vector3(-120, 0, 15), "Arm.R": Vector3(-120, 0, -15)}, RigAnimator.SNAP],
		[0.7, {"Rig:p": Vector3(0, 0.2, 0), "Arm.L": Vector3(-165, 0, 15), "Arm.R": Vector3(-165, 0, -15), "Head": _x(-10)}, RigAnimator.SETTLE],
		[0.88, {"Rig:p": Vector3(0, 0, 0), "Arm.L": Vector3(-100, 0, 10), "Arm.R": Vector3(-100, 0, -10)}, RigAnimator.SNAP],
	])
	# Defeat: slumps and stays that way.
	a.clip("Defeat", 1.2, [
		[0.6, {"Hips": _x(32), "Head": _x(28), "Rig:p": Vector3(0, -0.07, 0.02), "Arm.L": _x(8), "Arm.R": _x(8), "Leg.L": _x(-10), "Leg.R": _x(-10)}, RigAnimator.SETTLE],
		[1.2, {"Hips": _x(36), "Head": _x(32), "Rig:p": Vector3(0, -0.08, 0.02), "Arm.L": _x(10), "Arm.R": _x(10), "Leg.L": _x(-10), "Leg.R": _x(-10)}],
	], false, true)
	return a.build()


static func _attack_poses(style: StringName) -> Array:
	match style:
		&"punch":
			return [
				[0.18, {"Arm.R": Vector3(40, 0, -10), "Hips": Vector3(-6, -14, 0), "Rig:p": Vector3(0, 0, -0.06)}, RigAnimator.SETTLE],
				[0.32, {"Arm.R": _x(-85), "Hips": Vector3(14, 12, 0), "Rig:p": Vector3(0, 0, 0.2), "Arm.L": _x(25)}, RigAnimator.SNAP],
				[0.5, {"Arm.R": _x(-80), "Hips": Vector3(12, 10, 0), "Rig:p": Vector3(0, 0, 0.18), "Arm.L": _x(25)}, RigAnimator.SETTLE],
			]
		&"shoot":
			return [
				[0.25, {"Arm.L": _x(-90), "Arm.R": Vector3(-90, 0, -35), "Hips": _x(-4), "Head": _x(-4)}, RigAnimator.SETTLE],
				[0.45, {"Arm.L": _x(-92), "Arm.R": Vector3(-80, 0, -48), "Hips": _x(-4)}],
				[0.52, {"Arm.L": _x(-95), "Arm.R": Vector3(-85, 0, -10), "Rig:p": Vector3(0, 0, -0.05)}, RigAnimator.SNAP],
			]
		_:
			return [
				[0.2, {"Arm.R": Vector3(-160, 0, -15), "Hips": _x(-10), "Head": _x(-8), "Rig:p": Vector3(0, 0, -0.05), "Arm.L": _x(-20)}, RigAnimator.SETTLE],
				[0.3, {"Arm.R": Vector3(-170, 0, -15), "Hips": _x(-12), "Head": _x(-8), "Rig:p": Vector3(0, 0, -0.06), "Arm.L": _x(-20)}],
				[0.4, {"Arm.R": Vector3(-35, 0, 8), "Hips": _x(20), "Head": _x(8), "Rig:p": Vector3(0, 0, 0.22), "Arm.L": _x(30)}, RigAnimator.SNAP],
				[0.55, {"Arm.R": Vector3(-30, 0, 8), "Hips": _x(18), "Rig:p": Vector3(0, 0, 0.2), "Arm.L": _x(30)}, RigAnimator.SETTLE],
			]


static func _x(degrees: float) -> Vector3:
	return Vector3(degrees, 0, 0)


static func _z(degrees: float) -> Vector3:
	return Vector3(0, 0, degrees)
