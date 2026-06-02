extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer

const MAP_WIDTH := 100
const MAP_HEIGHT := 100

func _ready():
	randomize()
	generate_world()

	$Camera2D.position = Vector2(
		MAP_WIDTH * 16,
		MAP_HEIGHT * 16
	)

func generate_world():
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var r := randf()
			var source_id := 0

			if r < 0.70:
				source_id = 0 # grass
			elif r < 0.85:
				source_id = 1 # forest
			elif r < 0.95:
				source_id = 2 # stone
			else:
				source_id = 3 # water

			tilemap.set_cell(Vector2i(x, y), source_id, Vector2i(0, 0))
