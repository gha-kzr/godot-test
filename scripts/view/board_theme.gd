@tool
class_name BoardTheme
extends Resource
## How the board looks. Plain colored boxes by default; set the scenes to use an asset pack.

## World height of one terrain level.
@export_range(0.1, 2.0) var level_height := 0.5
## Depth of the column below a height-0 cell.
@export_range(0.1, 2.0) var base_thickness := 0.5
## Fraction of a cell the block covers; the gaps read as grid lines.
@export_range(0.5, 1.0) var block_fill := 0.96
@export var floor_color := Color(0.42, 0.56, 0.36)
## Higher cells are lightened by this much per level, so heights read at a glance.
@export_range(0.0, 0.3) var lighten_per_level := 0.08
@export var obstacle_color := Color(0.48, 0.44, 0.4)
@export var pit_color := Color(0.04, 0.04, 0.06)
## Cartoon shading for the terrain: a hard light / shadow step instead of a smooth gradient.
@export var toon := true
## Speckle on the terrain, as a fraction of brightness (0 for flat colors).
@export_range(0.0, 0.3) var noise_strength := 0.05

@export_group("Highlights")
## The start zone while placing heroes.
@export var zone_color := Color(0.2, 0.85, 0.75, 0.4)
@export var reach_color := Color(0.3, 0.6, 1.0, 0.45)
@export var path_color := Color(1.0, 1.0, 1.0, 0.6)
@export var range_color := Color(1.0, 0.55, 0.15, 0.4)
## In range but out of line of sight: shown faded, so it's clear why it can't be aimed at.
@export var range_blocked_color := Color(0.35, 0.18, 0.1, 0.45)
@export var area_color := Color(1.0, 0.2, 0.15, 0.55)

@export_group("Scenes")
## Replaces a floor cell's placeholder column. Instanced with its origin at the cell's
## top center; the model should extend downward to the base.
@export var floor_scene: PackedScene
## Models replacing the placeholder block on an obstacle cell, one picked per cell. Each is
## stretched to fill the obstacle's cube exactly (one cell wide and deep, `Grid.obstacle_levels`
## levels tall) and stands on the cell's top: rocks, crates, statues fit; what is drawn is
## what blocks line of sight. Static models only.
@export var obstacle_scenes: Array[PackedScene] = []
