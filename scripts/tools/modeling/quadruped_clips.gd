class_name QuadrupedClips
extends RefCounted
## The animation set of a four-legged model: Idle, Walk (a trot), Attack (a lunging bite), Cast
## (a howl), Hit, Death, Victory, Defeat. Joints: Rig (the whole body, at the feet), Body (the
## trunk, at its center), Head, Jaw (opening is a positive X rotation), Tail (swishes around Y),
## Leg.FL, Leg.FR, Leg.BL, Leg.BR (swing forward with a negative X rotation).
## Options: `stride` (leg swing, degrees), `lie` (how far the dead body is lifted so it lies on
## its side: half its width).


static func animate(kit: ModelKit, options := {}) -> AnimationPlayer:
	var stride: float = options.get("stride", 32.0)
	var lie: float = options.get("lie", 0.17)
	var a := RigAnimator.new(kit)
	a.clip("Idle", 1.6, [
		[0.0, {"Tail": _y(-10)}],
		[0.8, {"Body:p": Vector3(0, 0.015, 0), "Head": _x(-3), "Tail": _y(10)}],
		[1.6, {"Tail": _y(-10)}],
	], true)
	var hop := Vector3(0, 0.045, 0)
	a.clip("Walk", 0.45, [
		[0.0, {"Leg.FL": _x(-stride), "Leg.BR": _x(-stride), "Leg.FR": _x(stride), "Leg.BL": _x(stride), "Tail": _y(-12), "Body": Vector3(0, 0, 2)}],
		[0.11, {"Body:p": hop, "Head": _x(-3)}],
		[0.225, {"Leg.FL": _x(stride), "Leg.BR": _x(stride), "Leg.FR": _x(-stride), "Leg.BL": _x(-stride), "Tail": _y(12), "Body": Vector3(0, 0, -2)}],
		[0.34, {"Body:p": hop, "Head": _x(-3)}],
		[0.45, {"Leg.FL": _x(-stride), "Leg.BR": _x(-stride), "Leg.FR": _x(stride), "Leg.BL": _x(stride), "Tail": _y(-12), "Body": Vector3(0, 0, 2)}],
	], true)
	# Attack: rears back with the jaw open, springs forward, snaps shut.
	a.clip("Attack", 0.65, [
		[0.17, {"Rig:p": Vector3(0, 0, -0.1), "Body": _x(-9), "Head": _x(-12), "Jaw": _x(38), "Leg.FL": _x(-10), "Leg.FR": _x(-10)}, RigAnimator.SETTLE],
		[0.3, {"Rig:p": Vector3(0, 0.05, 0.32), "Body": _x(4), "Head": _x(14), "Jaw": _x(42), "Leg.FL": _x(-35), "Leg.FR": _x(-35), "Leg.BL": _x(25), "Leg.BR": _x(25)}, RigAnimator.SNAP],
		[0.38, {"Rig:p": Vector3(0, 0, 0.32), "Body": _x(6), "Head": _x(18), "Jaw": _x(0), "Leg.FL": _x(-25), "Leg.FR": _x(-25)}],
		[0.5, {"Rig:p": Vector3(0, 0, 0.28), "Body": _x(4), "Head": _x(10)}, RigAnimator.SETTLE],
	])
	# Cast: head thrown back in a howl.
	a.clip("Cast", 0.9, [
		[0.25, {"Body": _x(-12), "Head": _x(-42), "Jaw": _x(36), "Tail": _y(0), "Rig:p": Vector3(0, 0.02, 0)}, RigAnimator.SETTLE],
		[0.65, {"Body": _x(-14), "Head": _x(-46), "Jaw": _x(40), "Rig:p": Vector3(0, 0.03, 0)}],
		[0.78, {"Body": _x(4), "Head": _x(12), "Jaw": _x(8), "Rig:p": Vector3(0, 0, 0.1)}, RigAnimator.SNAP],
	])
	a.clip("Hit", 0.4, [
		[0.08, {"Rig": _x(-10), "Rig:p": Vector3(0, 0, -0.12), "Head": _x(-22), "Jaw": _x(25), "Tail": _y(25)}, RigAnimator.SETTLE],
	])
	a.clip("Death", 0.5, [
		[0.12, {"Rig": _x(-8), "Rig:p": Vector3(0, 0.03, -0.05), "Head": _x(-20), "Jaw": _x(25)}, RigAnimator.SETTLE],
		[0.5, {"Rig": _z(90), "Rig:p": Vector3(0, lie, 0), "Head": _x(10), "Jaw": _x(15), "Leg.FL": _x(-30), "Leg.FR": _x(-20), "Leg.BL": _x(25), "Leg.BR": _x(30)}, RigAnimator.SNAP],
	], false, true)
	a.clip("Victory", 1.0, [
		[0.15, {"Body": _x(8), "Rig:p": Vector3(0, -0.04, 0)}],
		[0.35, {"Body": _x(-14), "Head": _x(-44), "Jaw": _x(38), "Rig:p": Vector3(0, 0.22, 0), "Leg.FL": _x(-50), "Leg.FR": _x(-50)}, RigAnimator.SETTLE],
		[0.55, {"Body": _x(-4), "Head": _x(-20), "Jaw": _x(10), "Rig:p": Vector3(0, 0, 0)}, RigAnimator.SNAP],
		[0.75, {"Body": _x(-14), "Head": _x(-44), "Jaw": _x(38), "Rig:p": Vector3(0, 0.18, 0), "Leg.FL": _x(-50), "Leg.FR": _x(-50)}, RigAnimator.SETTLE],
		[0.92, {"Rig:p": Vector3(0, 0, 0)}, RigAnimator.SNAP],
	])
	a.clip("Defeat", 1.2, [
		[0.6, {"Body": _x(14), "Head": _x(42), "Rig:p": Vector3(0, -0.12, 0), "Tail": _y(0), "Leg.FL": _x(20), "Leg.FR": _x(20), "Leg.BL": _x(-20), "Leg.BR": _x(-20)}, RigAnimator.SETTLE],
		[1.2, {"Body": _x(16), "Head": _x(46), "Rig:p": Vector3(0, -0.14, 0), "Leg.FL": _x(22), "Leg.FR": _x(22), "Leg.BL": _x(-22), "Leg.BR": _x(-22)}],
	], false, true)
	return a.build()


static func _x(degrees: float) -> Vector3:
	return Vector3(degrees, 0, 0)


static func _y(degrees: float) -> Vector3:
	return Vector3(0, degrees, 0)


static func _z(degrees: float) -> Vector3:
	return Vector3(0, 0, degrees)
