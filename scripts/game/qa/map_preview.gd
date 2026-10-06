class_name MapPreview
extends Control
## A map drawn from above, for the QA screen: one square per cell, lighter the higher it
## stands, blocks in grey, holes in black, the start zone in teal and enemy spawns in red.

const GROUND := Color(0.32, 0.5, 0.3)
const HIGH_GROUND := Color(0.72, 0.85, 0.55)
const BLOCK := Color(0.55, 0.55, 0.58)
const HOLE := Color(0.05, 0.05, 0.07)
const ZONE := Color(0.25, 0.85, 0.78)
const ENEMY := Color(0.95, 0.3, 0.25)
## The highest level drawn with the lightest green.
const TOP_LEVEL := 4

## What the two start areas look like: a square for the heroes' zone, a dot for the enemies' spawns.
## A PvP lobby draws both as squares, in the teams' colours.
var zone_color := ZONE
var enemy_color := ENEMY
var enemy_as_square := false

var _parsed: MapData.ParseResult


func show_map(map: MapData) -> void:
	_parsed = map.parse() if map != null else null
	queue_redraw()


func _draw() -> void:
	if _parsed == null or _parsed.grid == null:
		return
	var grid := _parsed.grid
	var cell := floorf(minf(size.x / grid.size.x, size.y / grid.size.y))
	var origin := ((size - Vector2(grid.size) * cell) / 2.0).floor()
	for y in grid.size.y:
		for x in grid.size.x:
			var at := Vector2i(x, y)
			var color := GROUND.lerp(HIGH_GROUND, clampf(grid.height_at(at) / float(TOP_LEVEL), 0.0, 1.0))
			match grid.type_at(at):
				Grid.CellType.OBSTACLE: color = BLOCK
				Grid.CellType.HOLE: color = HOLE
			var square := Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell)
			draw_rect(square.grow(-1.0), color)
			if at in _parsed.player_spawns:
				draw_rect(square.grow(-cell * 0.25), zone_color)
			elif at in _parsed.enemy_spawns:
				if enemy_as_square:
					draw_rect(square.grow(-cell * 0.25), enemy_color)
				else:
					draw_circle(square.get_center(), cell * 0.3, enemy_color)
