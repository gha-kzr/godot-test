class_name StatusInfo
extends RefCounted
## A status as the HUD shows it. Plain data, built by the controller from the battle state.

var display_name := ""
var short_label := ""
var color := Color.WHITE
var turns_left := 0
var description := ""
var is_positive := false
var icon: Texture2D
## The status itself, to tell two statuses apart (a recast replaces the previous one).
var data: StatusData
## AP and MP the status adds to its carrier's maxima.
var ap_bonus := 0
var mp_bonus := 0
## Whether the carrier's current turn counts down this status (see StatusInstance.counting).
var counting := false


static func from_data(status: StatusData, turns: int, is_counting := false) -> StatusInfo:
	var info := StatusInfo.new()
	info.data = status
	info.display_name = status.display_name
	info.short_label = status.short_label
	info.color = status.color
	info.turns_left = turns
	info.description = status.describe()
	info.is_positive = status.is_positive
	info.icon = status.display_icon()
	info.counting = is_counting
	for modifier in status.modifiers:
		if modifier.stat == StatModifier.Stat.AP:
			info.ap_bonus += modifier.amount
		elif modifier.stat == StatModifier.Stat.MP:
			info.mp_bonus += modifier.amount
	return info


## "1 turn" / "3 turns".
func turns_text() -> String:
	return tr_n("%d turn", "%d turns", turns_left) % turns_left
