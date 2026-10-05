@tool
class_name MapTypology
extends Resource
## A kind of generated map (the board's shape), with its knobs. MapGenerator builds the height
## field and the obstacles / holes from it, seeded by the floor (noise included), then places
## the start zone and the enemies. Tower bands draw one by weight (FloorBand.map_typologies);
## a stage can fix one.

enum Kind {
	OPEN_FIELD,  ## Plateaus on flat ground, a sprinkle of rocks and holes.
	MOUNTAIN,  ## Height rises to a peak near the centre: slopes and ridges to fight over.
	CRATER,  ## A high rim around a low centre.
	ISLANDS,  ## Raised islands over holes, joined by one-cell bridges.
	CANYON,  ## A chasm across the map with a few crossings.
	RUINS,  ## Walls of blocks forming rooms and corridors, with doorways.
}

@export var kind := Kind.OPEN_FIELD
## For designers (not shown to players).
@export var label := ""
## The highest level the shape reaches (the walking rule smooths it to steps of one).
@export_range(1, 5) var max_height := 2
## Plateaus per 100 cells (open field).
@export_range(0.0, 20.0) var plateaus_per_100_cells := 4.0
## The noise's scale: higher is busier terrain (islands' shapes, height ripples).
@export_range(0.02, 0.6) var noise_frequency := 0.15
## How much of the map is land for islands (0 to 1).
@export_range(0.2, 0.9) var land_share := 0.6
## Crossings over a canyon.
@export_range(1, 5) var crossings := 2
## Room size for ruins, walls included.
@export_range(3, 8) var room_size := 5
## Scattered rocks and holes, on top of the shape's own.
@export_range(0.0, 0.3) var obstacle_density := 0.05
@export_range(0.0, 0.3) var hole_density := 0.02


func get_validation_errors() -> PackedStringArray:
	return PackedStringArray()
