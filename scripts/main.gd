extends Node2D

# V2 jouable de LivingKingdom.
# La carte reste procédurale, mais le village est composé de vrais sprites Tiny Town lisibles.

const VillagerScript := preload("res://scripts/villager.gd")

const MAP_WIDTH := 200
const MAP_HEIGHT := 200
const TILE_SIZE := 16
const VILLAGER_COUNT := 5
const VILLAGE_NAME := "Riveterre"
const DAY_DURATION_SECONDS := 20.0
const VILLAGE_CENTER_TILE := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
const VILLAGE_SAFE_RADIUS := 18

const SOURCE_GRASS := 0
const SOURCE_FOREST := 1
const SOURCE_ROCK := 2
const SOURCE_DIRT := 3

const TERRAIN_DEFINITIONS := [
	{"source_id": SOURCE_GRASS, "path": "res://assets/tiny_town/terrain/grass.png"},
	{"source_id": SOURCE_FOREST, "path": "res://assets/tiny_town/terrain/forest.png"},
	{"source_id": SOURCE_ROCK, "path": "res://assets/tiny_town/terrain/rock.png"},
	{"source_id": SOURCE_DIRT, "path": "res://assets/tiny_town/terrain/dirt.png"},
]

const TREE_TEXTURES := [
	"res://assets/tiny_town/objects/tree_pine.png",
	"res://assets/tiny_town/objects/tree_round.png",
	"res://assets/tiny_town/objects/tree_trunk.png",
]

const ROCK_TEXTURES := [
	"res://assets/tiny_town/objects/rock_large.png",
	"res://assets/tiny_town/objects/rock_curve.png",
]

const HOUSE_LAYOUT := [
	["res://assets/tiny_town/houses/roof_red_left.png", "res://assets/tiny_town/houses/roof_red_mid.png", "res://assets/tiny_town/houses/roof_red_right.png"],
	["res://assets/tiny_town/houses/wall_red_left.png", "res://assets/tiny_town/houses/wall_red_mid.png", "res://assets/tiny_town/houses/wall_red_right.png"],
	["res://assets/tiny_town/houses/window_wood.png", "res://assets/tiny_town/houses/door_wood.png", "res://assets/tiny_town/houses/window_wood.png"],
]

const FIRST_NAMES := ["Aline", "Bastien", "Clara", "Dorian", "Elise", "Firmin", "Gaelle", "Hugo"]
const FAMILY_NAMES := ["Boisclair", "Pierrefeu", "Valbrun", "Ruisseau", "Hauteherbe", "Lenoir"]

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var camera: Camera2D = $Camera2D
@onready var nature_root: Node2D = $Nature
@onready var village_root: Node2D = $Village
@onready var villagers_root: Node2D = $Villagers
@onready var hud_label: Label = $HUD/InfoLabel

var biome_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var current_day := 1
var elapsed_day_time := 0.0
var forest_tiles: Array[Vector2i] = []
var rock_tiles: Array[Vector2i] = []

func _ready() -> void:
	randomize()
	_setup_scene_roots()
	_setup_tilemap()
	_setup_noise()
	generate_world()
	create_nature_details()
	create_village()
	create_villagers()
	center_existing_camera_on_village()
	_update_hud()

func _process(delta: float) -> void:
	# Le compteur avance en temps réel pour donner un premier rythme de simulation.
	elapsed_day_time += delta
	if elapsed_day_time >= DAY_DURATION_SECONDS:
		elapsed_day_time -= DAY_DURATION_SECONDS
		current_day += 1
		_update_hud()

func _setup_scene_roots() -> void:
	# Le tri Y rend les sprites Tiny Town plus lisibles quand ils se chevauchent.
	nature_root.y_sort_enabled = true
	village_root.y_sort_enabled = true
	villagers_root.y_sort_enabled = true

func _setup_tilemap() -> void:
	# Le TileSet est construit par code pour garder la scène légère et utiliser les assets Tiny Town.
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for definition in TERRAIN_DEFINITIONS:
		var source := TileSetAtlasSource.new()
		source.texture = load(definition["path"])
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i.ZERO)
		tile_set.add_source(source, definition["source_id"])

	tilemap.tile_set = tile_set

func _setup_noise() -> void:
	# FastNoiseLite regroupe naturellement les biomes en grandes zones cohérentes.
	biome_noise.seed = randi()
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.frequency = 0.023
	biome_noise.fractal_octaves = 4
	biome_noise.fractal_gain = 0.55

	# Un second bruit affine les transitions sans casser les grands regroupements.
	detail_noise.seed = randi()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.075
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_gain = 0.45

func generate_world() -> void:
	# Génère une carte complète de 200x200 cases avec herbe, forêt, roche et terre.
	tilemap.clear()
	forest_tiles.clear()
	rock_tiles.clear()

	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			var position := Vector2i(x, y)
			var source_id := _pick_biome_source(position)
			tilemap.set_cell(position, source_id, Vector2i.ZERO)
			if _is_near_village(position):
				continue
			if source_id == SOURCE_FOREST:
				forest_tiles.append(position)
			elif source_id == SOURCE_ROCK:
				rock_tiles.append(position)

func _pick_biome_source(tile_position: Vector2i) -> int:
	var biome_value := biome_noise.get_noise_2d(tile_position.x, tile_position.y)
	var detail_value := detail_noise.get_noise_2d(tile_position.x, tile_position.y) * 0.22
	var value := biome_value + detail_value

	if value < -0.30:
		return SOURCE_ROCK
	if value < -0.08:
		return SOURCE_DIRT
	if value < 0.30:
		return SOURCE_GRASS
	return SOURCE_FOREST

func create_nature_details() -> void:
	# Les biomes ne restent pas plats : des groupes de sprites montrent les forêts et rochers.
	_clear_children(nature_root)
	_spawn_grouped_objects(forest_tiles, TREE_TEXTURES, 90, 7, 1.65)
	_spawn_grouped_objects(rock_tiles, ROCK_TEXTURES, 42, 5, 1.35)

func _spawn_grouped_objects(source_tiles: Array[Vector2i], texture_paths: Array, cluster_count: int, cluster_size: int, sprite_scale: float) -> void:
	if source_tiles.is_empty():
		return

	for cluster_index in range(cluster_count):
		var origin: Vector2i = source_tiles.pick_random()
		for object_index in range(randi_range(2, cluster_size)):
			var tile_position: Vector2i = origin + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
			if not Rect2i(Vector2i.ZERO, Vector2i(MAP_WIDTH, MAP_HEIGHT)).has_point(tile_position):
				continue
			if _is_near_village(tile_position):
				continue
			_add_sprite(nature_root, texture_paths.pick_random(), _tile_to_world(tile_position), sprite_scale)

func create_village() -> void:
	# Le centre est volontairement dégagé pour que Riveterre soit évident au lancement.
	_clear_children(village_root)
	_paint_village_ground()
	_add_paths()
	_add_houses()
	_add_fences_and_sign()

func _paint_village_ground() -> void:
	for x in range(VILLAGE_CENTER_TILE.x - 13, VILLAGE_CENTER_TILE.x + 14):
		for y in range(VILLAGE_CENTER_TILE.y - 11, VILLAGE_CENTER_TILE.y + 12):
			var tile_position: Vector2i = Vector2i(x, y)
			if (tile_position - VILLAGE_CENTER_TILE).length() <= 15.0:
				tilemap.set_cell(tile_position, SOURCE_GRASS, Vector2i.ZERO)

func _add_paths() -> void:
	# Chemins en terre en croix et petite place centrale.
	for x in range(VILLAGE_CENTER_TILE.x - 14, VILLAGE_CENTER_TILE.x + 15):
		for width in range(-1, 2):
			tilemap.set_cell(Vector2i(x, VILLAGE_CENTER_TILE.y + width), SOURCE_DIRT, Vector2i.ZERO)
	for y in range(VILLAGE_CENTER_TILE.y - 10, VILLAGE_CENTER_TILE.y + 11):
		for width in range(-1, 2):
			tilemap.set_cell(Vector2i(VILLAGE_CENTER_TILE.x + width, y), SOURCE_DIRT, Vector2i.ZERO)
	for x in range(VILLAGE_CENTER_TILE.x - 3, VILLAGE_CENTER_TILE.x + 4):
		for y in range(VILLAGE_CENTER_TILE.y - 3, VILLAGE_CENTER_TILE.y + 4):
			tilemap.set_cell(Vector2i(x, y), SOURCE_DIRT, Vector2i.ZERO)

func _add_houses() -> void:
	# Quatre maisons Tiny Town bien séparées encadrent la place centrale.
	_add_house(VILLAGE_CENTER_TILE + Vector2i(-9, -7), "Maison Nord-Ouest")
	_add_house(VILLAGE_CENTER_TILE + Vector2i(6, -7), "Maison Nord-Est")
	_add_house(VILLAGE_CENTER_TILE + Vector2i(-9, 5), "Maison Sud-Ouest")
	_add_house(VILLAGE_CENTER_TILE + Vector2i(6, 5), "Maison Sud-Est")

func _add_house(top_left_tile: Vector2i, building_name: String) -> void:
	var root := Node2D.new()
	root.name = building_name
	root.position = _tile_to_world(top_left_tile)
	village_root.add_child(root)

	for row in range(HOUSE_LAYOUT.size()):
		for column in range(HOUSE_LAYOUT[row].size()):
			var part := Sprite2D.new()
			part.texture = load(HOUSE_LAYOUT[row][column])
			part.position = Vector2(column * TILE_SIZE, row * TILE_SIZE)
			part.scale = Vector2(1.35, 1.35)
			root.add_child(part)

func _add_fences_and_sign() -> void:
	for x in range(-7, 8):
		if abs(x) <= 2:
			continue
		_add_sprite(village_root, "res://assets/tiny_town/village/fence.png", _tile_to_world(VILLAGE_CENTER_TILE + Vector2i(x, -5)), 1.0)
		_add_sprite(village_root, "res://assets/tiny_town/village/fence.png", _tile_to_world(VILLAGE_CENTER_TILE + Vector2i(x, 5)), 1.0)
	_add_sprite(village_root, "res://assets/tiny_town/village/sign.png", _tile_to_world(VILLAGE_CENTER_TILE + Vector2i(0, -4)), 1.35)

func create_villagers() -> void:
	_clear_children(villagers_root)
	var village_center := _tile_to_world(VILLAGE_CENTER_TILE)
	var movement_area := Rect2(village_center - Vector2(125.0, 95.0), Vector2(250.0, 190.0))

	for index in range(VILLAGER_COUNT):
		var villager = Node2D.new()
		villager.set_script(VillagerScript)
		villagers_root.add_child(villager)
		villager.setup(_random_villager_name(), movement_area, village_center + Vector2(randf_range(-54.0, 54.0), randf_range(-38.0, 38.0)))

func _random_villager_name() -> String:
	return "%s %s" % [FIRST_NAMES.pick_random(), FAMILY_NAMES.pick_random()]

func center_existing_camera_on_village() -> void:
	# La Camera2D existante est conservée, centrée sur le village et dézoomée pour une lecture agréable.
	camera.position = _tile_to_world(VILLAGE_CENTER_TILE)
	camera.zoom = Vector2(0.62, 0.62)

func _update_hud() -> void:
	hud_label.text = "Jour %d\nVillage : %s\nPopulation : %d" % [current_day, VILLAGE_NAME, VILLAGER_COUNT]

func _add_sprite(parent: Node, texture_path: String, world_position: Vector2, sprite_scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.position = world_position
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	parent.add_child(sprite)
	return sprite

func _is_near_village(tile_position: Vector2i) -> bool:
	return (tile_position - VILLAGE_CENTER_TILE).length() <= VILLAGE_SAFE_RADIUS

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

func _tile_to_world(tile_position: Vector2i) -> Vector2:
	return Vector2(tile_position.x * TILE_SIZE + TILE_SIZE * 0.5, tile_position.y * TILE_SIZE + TILE_SIZE * 0.5)
