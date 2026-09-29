@tool
class_name RunState
extends RefCounted
## A run in progress (tower or stage), saved in the profile between floors: where it is,
## each hero's HP, the boons picked, and a pending boss offer.

enum Mode { TOWER, STAGE }

var mode := Mode.TOWER
var stage: StageData  ## Stage runs only.
var floor_number := 1  ## The next floor to play.
var start_floor := 1
## Current HP per party slot (the profile's party order); -1: full.
var hero_hp: Array[int] = []
var boons: Array[BoonData] = []
## After a boss: a boon from the offer or a full heal is pending (the offer may be empty,
## e.g. its boon files are gone: then only the heal is offered).
var choice_pending := false
var boss_offer: Array[BoonData] = []


func awaiting_choice() -> bool:
	return choice_pending


func to_dict() -> Dictionary:
	return {"mode": mode, "stage": Profile._ref(stage) if stage != null else null, "floor": floor_number,
			"start_floor": start_floor, "hero_hp": hero_hp.duplicate(),
			"boons": boons.map(func(b: BoonData) -> Dictionary: return Profile._ref(b)),
			"boss_offer": boss_offer.map(func(b: BoonData) -> Dictionary: return Profile._ref(b)),
			"choice_pending": choice_pending}


## Null when the saved run can't be resumed (e.g. its stage no longer exists).
static func from_dict(data: Dictionary) -> RunState:
	var run := RunState.new()
	run.mode = Mode.STAGE if _int(data.get("mode"), 0) == Mode.STAGE else Mode.TOWER
	if run.mode == Mode.STAGE:
		run.stage = _load(data.get("stage")) as StageData
		if run.stage == null:
			return null
	run.floor_number = maxi(1, _int(data.get("floor"), 1))
	run.start_floor = maxi(1, _int(data.get("start_floor"), 1))
	for value: Variant in data.get("hero_hp", []) if data.get("hero_hp") is Array else []:
		run.hero_hp.append(_int(value, -1))
	for key in ["boons", "boss_offer"]:
		var list: Array = data.get(key, []) if data.get(key) is Array else []
		for ref: Variant in list:
			var boon := _load(ref) as BoonData
			if boon != null:
				(run.boons if key == "boons" else run.boss_offer).append(boon)
	var pending: Variant = data.get("choice_pending")
	run.choice_pending = pending if pending is bool else not run.boss_offer.is_empty()
	return run


static func _int(value: Variant, default: int) -> int:
	return int(value) if value is int or value is float else default


static func _load(ref: Variant) -> Resource:
	var path := Profile._resolve_path(ref)
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
