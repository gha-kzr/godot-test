class_name FloaterClips
extends RefCounted
## The animation set of a model that hovers (a ghost, a spirit): Idle, Walk (a glide), Attack,
## Cast, Hit, Death, Victory, Defeat. Joints: Rig (the whole body, at the floor), Body (the
## trunk, where it leans and sways), Arm.L, Arm.R (swing forward with a negative X rotation, out
## to the side with a negative (right) / positive (left) Z rotation), Tail (swishes around Y).


static func animate(kit: ModelKit, _options := {}) -> AnimationPlayer:
	var a := RigAnimator.new(kit)
	a.clip("Idle", 2.0, [
		[0.0, {"Tail": _y(-14), "Arm.L": _z(6), "Arm.R": _z(-6)}],
		[1.0, {"Rig:p": Vector3(0, 0.08, 0), "Tail": _y(14), "Arm.L": _z(-4), "Arm.R": _z(4), "Body": _x(-3)}],
		[2.0, {"Tail": _y(-14), "Arm.L": _z(6), "Arm.R": _z(-6)}],
	], true)
	a.clip("Walk", 0.8, [
		[0.0, {"Body": Vector3(14, 0, 5), "Tail": _y(-18), "Arm.L": _x(38), "Arm.R": _x(30)}],
		[0.2, {"Rig:p": Vector3(0, 0.06, 0), "Body": Vector3(14, 0, 0), "Arm.L": _x(30), "Arm.R": _x(38)}],
		[0.4, {"Body": Vector3(14, 0, -5), "Tail": _y(18), "Arm.L": _x(38), "Arm.R": _x(30)}],
		[0.6, {"Rig:p": Vector3(0, 0.06, 0), "Body": Vector3(14, 0, 0), "Arm.L": _x(30), "Arm.R": _x(38)}],
		[0.8, {"Body": Vector3(14, 0, 5), "Tail": _y(-18), "Arm.L": _x(38), "Arm.R": _x(30)}],
	], true)
	# Attack: pulls back, then swoops forward claws first.
	a.clip("Attack", 0.65, [
		[0.2, {"Body": _x(-16), "Rig:p": Vector3(0, 0.05, -0.1), "Arm.L": Vector3(-30, 0, 55), "Arm.R": Vector3(-30, 0, -55)}, RigAnimator.SETTLE],
		[0.36, {"Body": _x(24), "Rig:p": Vector3(0, -0.03, 0.34), "Arm.L": Vector3(-115, 0, 8), "Arm.R": Vector3(-115, 0, -8)}, RigAnimator.SNAP],
		[0.5, {"Body": _x(18), "Rig:p": Vector3(0, 0, 0.3), "Arm.L": Vector3(-100, 0, 10), "Arm.R": Vector3(-100, 0, -10)}, RigAnimator.SETTLE],
	])
	a.clip("Cast", 0.9, [
		[0.3, {"Rig:p": Vector3(0, 0.22, 0), "Body": _x(-10), "Arm.L": Vector3(-40, 0, 85), "Arm.R": Vector3(-40, 0, -85)}, RigAnimator.SETTLE],
		[0.55, {"Rig:p": Vector3(0, 0.26, 0), "Body": _x(-12), "Arm.L": Vector3(-50, 0, 95), "Arm.R": Vector3(-50, 0, -95), "Tail": _y(20)}],
		[0.7, {"Rig:p": Vector3(0, 0.05, 0.1), "Body": _x(14), "Arm.L": Vector3(-100, 0, 10), "Arm.R": Vector3(-100, 0, -10)}, RigAnimator.SNAP],
	])
	a.clip("Hit", 0.4, [
		[0.08, {"Rig": _x(-10), "Rig:p": Vector3(0, 0, -0.14), "Body": _x(-12), "Arm.L": _z(40), "Arm.R": _z(-40)}, RigAnimator.SETTLE],
	])
	a.clip("Death", 0.5, [
		[0.12, {"Body": _x(-12), "Rig:p": Vector3(0, 0.1, -0.05), "Arm.L": _z(50), "Arm.R": _z(-50)}, RigAnimator.SETTLE],
		[0.5, {"Rig": _x(-70), "Rig:p": Vector3(0, -0.25, -0.1), "Arm.L": _z(70), "Arm.R": _z(-70)}, RigAnimator.SNAP],
	], false, true)
	a.clip("Victory", 1.2, [
		[0.3, {"Rig:p": Vector3(0, 0.3, 0), "Arm.L": Vector3(-150, 0, 20), "Arm.R": Vector3(-150, 0, -20)}],
		[0.6, {"Rig": _y(-25), "Rig:p": Vector3(0, 0.35, 0), "Arm.L": Vector3(-150, 0, 20), "Arm.R": Vector3(-150, 0, -20)}],
		[0.9, {"Rig": _y(25), "Rig:p": Vector3(0, 0.25, 0), "Arm.L": Vector3(-150, 0, 20), "Arm.R": Vector3(-150, 0, -20)}],
	])
	a.clip("Defeat", 1.2, [
		[0.6, {"Rig:p": Vector3(0, -0.2, 0), "Body": _x(26), "Arm.L": _x(20), "Arm.R": _x(20)}, RigAnimator.SETTLE],
		[1.2, {"Rig:p": Vector3(0, -0.24, 0), "Body": _x(30), "Arm.L": _x(24), "Arm.R": _x(24)}],
	], false, true)
	return a.build()


static func _x(degrees: float) -> Vector3:
	return Vector3(degrees, 0, 0)


static func _y(degrees: float) -> Vector3:
	return Vector3(0, degrees, 0)


static func _z(degrees: float) -> Vector3:
	return Vector3(0, 0, degrees)
