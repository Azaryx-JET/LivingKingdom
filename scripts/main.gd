extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var resource_manager = $ResourceManager
@onready var history_log = $HistoryLog
@onready var village = $Village
@onready var stats_label: Label = $HUD/StatsPanel/MarginContainer/StatsLabel
@onready var history_label: Label = $HUD/HistoryPanel/MarginContainer/HistoryLabel

const MAP_WIDTH := 200
const MAP_HEIGHT := 200
const TILE_SIZE := 16
const GRASS_ATLAS := Vector2i(0, 0)
const FOREST_ATLAS := Vector2i(1, 0)
const STONE_ATLAS := Vector2i(2, 0)
const WATER_ATLAS := Vector2i(3, 0)
const FIELD_ATLAS := Vector2i(4, 0)

var resource_points := {
	"bois": [],
	"pierre": [],
	"nourriture": [],
}

func _ready() -> void:
	randomize()
	generate_world()
	camera.position = Vector2(MAP_WIDTH * TILE_SIZE / 2.0, MAP_HEIGHT * TILE_SIZE / 2.0)
	_connect_simulation()
	village.setup(tilemap, resource_manager, history_log, resource_points, Vector2i(MAP_WIDTH, MAP_HEIGHT))
	_update_stats()
	_update_history(history_log.get_recent_events())

func generate_world() -> void:
	resource_points["bois"].clear()
	resource_points["pierre"].clear()
	resource_points["nourriture"].clear()
	var village_center := Vector2i(int(MAP_WIDTH / 2), int(MAP_HEIGHT / 2))
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var tile: Vector2i = Vector2i(x, y)
			var distance_to_village := Vector2(float(tile.x - village_center.x), float(tile.y - village_center.y)).length()
			var atlas := GRASS_ATLAS
			if distance_to_village < 8.0:
				atlas = GRASS_ATLAS
			else:
				var r := randf()
				if r < 0.66:
					atlas = GRASS_ATLAS
				elif r < 0.82:
					atlas = FOREST_ATLAS
					resource_points["bois"].append(_tile_to_world(tile))
				elif r < 0.93:
					atlas = STONE_ATLAS
					resource_points["pierre"].append(_tile_to_world(tile))
				elif r < 0.97:
					atlas = FIELD_ATLAS
					resource_points["nourriture"].append(_tile_to_world(tile))
				else:
					atlas = WATER_ATLAS
			tilemap.set_cell(tile, 0, atlas)
	_ensure_nearby_resources(village_center)

func _connect_simulation() -> void:
	resource_manager.stocks_changed.connect(func(_stocks: Dictionary) -> void:
		_update_stats()
	)
	resource_manager.low_resource.connect(func(resource_name: String, amount: int) -> void:
		history_log.add_event(village.day, "Alerte : le stock de %s devient faible (%d)." % [resource_name, amount])
	)
	history_log.events_changed.connect(_update_history)
	village.stats_changed.connect(_update_stats)

func _update_stats() -> void:
	stats_label.text = "Jour %d\nVillage : %s\nPopulation : %d / %d\nBois : %d\nPierre : %d\nNourriture : %d" % [
		village.day,
		village.VILLAGE_NAME,
		village.get_population(),
		village.get_capacity(),
		resource_manager.get_amount("bois"),
		resource_manager.get_amount("pierre"),
		resource_manager.get_amount("nourriture"),
	]

func _update_history(events: Array[String]) -> void:
	history_label.text = "Journal historique\n" + "\n".join(PackedStringArray(events))

func _ensure_nearby_resources(center: Vector2i) -> void:
	for offset in [Vector2i(-9, -2), Vector2i(-10, 3), Vector2i(-7, 6), Vector2i(8, -5)]:
		var tile: Vector2i = center + offset
		tilemap.set_cell(tile, 0, FOREST_ATLAS)
		resource_points["bois"].append(_tile_to_world(tile))
	for offset in [Vector2i(7, 6), Vector2i(10, 5), Vector2i(11, -3)]:
		var tile: Vector2i = center + offset
		tilemap.set_cell(tile, 0, STONE_ATLAS)
		resource_points["pierre"].append(_tile_to_world(tile))
	for offset in [Vector2i(-5, -8), Vector2i(4, -9), Vector2i(6, 8)]:
		var tile: Vector2i = center + offset
		tilemap.set_cell(tile, 0, FIELD_ATLAS)
		resource_points["nourriture"].append(_tile_to_world(tile))

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
