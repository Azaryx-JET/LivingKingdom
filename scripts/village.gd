extends Node2D
class_name Village

signal stats_changed
signal villager_created(villager: Dictionary)
signal house_built(position: Vector2)

const TILE_SIZE := 16
const VILLAGE_NAME := "Riveterre"
const HOUSE_COST := {"bois": 80, "pierre": 40}
const BIRTH_FOOD_COST := 50
const JOBS := ["bûcheron", "mineur", "cueilleur", "bâtisseur"]
const FIRST_NAMES := ["Clara", "Dorian", "Mira", "Bastien", "Lina", "Hugo", "Ariane", "Noé", "Elise", "Robin", "Maël", "Iris"]

@export var day_duration := 24.0
@export var villager_speed := 58.0

var resource_manager
var history_log
var tilemap: TileMapLayer
var map_size := Vector2i(200, 200)
var resource_points := {
	"bois": [],
	"pierre": [],
	"nourriture": [],
}

var day := 1
var capacity := 6
var villagers: Array[Dictionary] = []
var village_tile := Vector2i(100, 100)
var village_position := Vector2.ZERO
var _day_progress := 0.0
var _used_name_counts := {}
var _house_count := 1
var _house_ring_index := 0
var _startup_jobs: Array[String] = []

func setup(p_tilemap: TileMapLayer, p_resource_manager, p_history_log, p_resource_points: Dictionary, p_map_size: Vector2i) -> void:
	tilemap = p_tilemap
	resource_manager = p_resource_manager
	history_log = p_history_log
	resource_points = p_resource_points
	map_size = p_map_size
	village_tile = Vector2i(int(map_size.x / 2), int(map_size.y / 2))
	village_position = _tile_to_world(village_tile)
	position = Vector2.ZERO
	_create_village_marker()
	_spawn_initial_house()
	history_log.add_event(day, "Fondation de %s." % VILLAGE_NAME)
	_startup_jobs = Array(JOBS.duplicate(), TYPE_STRING, "", null)
	_startup_jobs.shuffle()
	_startup_jobs.append(JOBS.pick_random())
	for i in range(5):
		spawn_villager(false)
	stats_changed.emit()

func _process(delta: float) -> void:
	_day_progress += delta
	if _day_progress >= day_duration:
		_day_progress -= day_duration
		_advance_day()
	_update_villagers(delta)
	resource_manager.check_alerts(day)

func spawn_villager(is_birth: bool = true) -> void:
	if villagers.size() >= capacity:
		return
	var name := _next_name()
	var job := _pick_job(is_birth)
	var visual := _create_villager_visual(name, job)
	var villager := {
		"name": name,
		"job": job,
		"hunger": randf_range(10.0, 35.0),
		"energy": randf_range(72.0, 100.0),
		"inventory": {"bois": 0, "pierre": 0, "nourriture": 0},
		"state": "decide",
		"target": village_position + _random_village_offset(),
		"timer": 0.0,
		"visual": visual,
		"logged_job_once": false,
	}
	visual.position = village_position + _random_village_offset()
	villagers.append(villager)
	villager_created.emit(villager)
	if is_birth:
		history_log.add_event(day, "%s rejoint le village." % name)
	stats_changed.emit()

func get_population() -> int:
	return villagers.size()

func get_capacity() -> int:
	return capacity

func build_house(builder_name: String) -> bool:
	if not _can_build_house():
		return false
	if not resource_manager.consume_many(HOUSE_COST):
		return false
	capacity += 3
	_house_count += 1
	var house_position := village_position + _next_house_offset()
	_create_house_visual(house_position)
	history_log.add_event(day, "%s construit une nouvelle maison." % builder_name)
	house_built.emit(house_position)
	stats_changed.emit()
	return true

func _advance_day() -> void:
	day += 1
	for villager in villagers:
		villager["hunger"] = min(100.0, float(villager["hunger"]) + 4.0)
	if day % 5 == 0 and resource_manager.get_amount("nourriture") >= BIRTH_FOOD_COST and villagers.size() < capacity:
		if resource_manager.consume("nourriture", BIRTH_FOOD_COST):
			spawn_villager(true)
	resource_manager.check_alerts(day)
	stats_changed.emit()

func _update_villagers(delta: float) -> void:
	for i in range(villagers.size()):
		var villager := villagers[i]
		villager["hunger"] = min(100.0, float(villager["hunger"]) + delta * 0.85)
		_auto_eat(villager)
		if float(villager["energy"]) < 18.0 and villager["state"] != "resting":
			_start_rest(villager)
		_match_state(villager, delta)
		villagers[i] = villager

func _match_state(villager: Dictionary, delta: float) -> void:
	match String(villager["state"]):
		"decide":
			_decide_next_task(villager)
		"travel_resource":
			_move_to_target(villager, delta, "harvest")
		"harvest":
			_harvest(villager, delta)
		"return_village":
			_move_to_target(villager, delta, "deposit")
		"deposit":
			_deposit(villager)
		"resting":
			_rest(villager, delta)
		"build", "building":
			_build(villager, delta)
		_:
			villager["state"] = "decide"

func _decide_next_task(villager: Dictionary) -> void:
	if float(villager["energy"]) < 35.0:
		_start_rest(villager)
		return
	var job := String(villager["job"])
	if job == "bâtisseur" and _can_build_house():
		villager["state"] = "build"
		villager["target"] = village_position + _next_house_offset(false)
		villager["timer"] = 2.5
		return
	var resource_name := _resource_for_job(job)
	villager["target"] = _pick_resource_point(resource_name)
	villager["current_resource"] = resource_name
	villager["state"] = "travel_resource"

func _move_to_target(villager: Dictionary, delta: float, next_state: String) -> void:
	var visual := villager["visual"] as Node2D
	var target := villager["target"] as Vector2
	var to_target := target - visual.position
	if to_target.length() <= 4.0:
		villager["state"] = next_state
		villager["timer"] = randf_range(1.2, 2.4)
		return
	visual.position += to_target.normalized() * villager_speed * delta
	villager["energy"] = max(0.0, float(villager["energy"]) - delta * 1.2)

func _harvest(villager: Dictionary, delta: float) -> void:
	villager["timer"] = float(villager["timer"]) - delta
	villager["energy"] = max(0.0, float(villager["energy"]) - delta * 4.0)
	if float(villager["timer"]) > 0.0:
		return
	var resource_name := String(villager.get("current_resource", _resource_for_job(String(villager["job"]))))
	var amount := randi_range(8, 16)
	villager["inventory"][resource_name] = int(villager["inventory"].get(resource_name, 0)) + amount
	villager["target"] = village_position + _random_village_offset()
	villager["state"] = "return_village"
	if not bool(villager["logged_job_once"]) or randf() < 0.25:
		history_log.add_event(day, "%s récolte %s %s." % [villager["name"], _article_for(resource_name), resource_name])
		villager["logged_job_once"] = true

func _deposit(villager: Dictionary) -> void:
	var inventory: Dictionary = villager["inventory"]
	var deposited := false
	for resource_name in inventory.keys():
		var amount := int(inventory[resource_name])
		if amount > 0:
			resource_manager.add_resource(resource_name, amount)
			inventory[resource_name] = 0
			deposited = true
	if deposited:
		stats_changed.emit()
	villager["state"] = "decide"

func _build(villager: Dictionary, delta: float) -> void:
	if String(villager["state"]) == "build":
		_move_to_target(villager, delta, "building")
		if String(villager["state"]) == "building":
			villager["timer"] = 2.5
		return
	villager["timer"] = float(villager.get("timer", 2.5)) - delta
	villager["energy"] = max(0.0, float(villager["energy"]) - delta * 5.5)
	if float(villager["timer"]) <= 0.0:
		build_house(String(villager["name"]))
		villager["state"] = "decide"

func _start_rest(villager: Dictionary) -> void:
	villager["state"] = "resting"
	villager["target"] = village_position + _random_village_offset()

func _rest(villager: Dictionary, delta: float) -> void:
	var visual := villager["visual"] as Node2D
	if visual.position.distance_to(villager["target"]) > 5.0:
		_move_to_target(villager, delta, "resting")
		return
	villager["energy"] = min(100.0, float(villager["energy"]) + delta * 9.0)
	if float(villager["energy"]) >= 82.0:
		villager["state"] = "decide"

func _auto_eat(villager: Dictionary) -> void:
	if float(villager["hunger"]) < 65.0:
		return
	if resource_manager.consume("nourriture", 3):
		villager["hunger"] = max(0.0, float(villager["hunger"]) - 38.0)
		if randf() < 0.12:
			history_log.add_event(day, "%s mange une ration du village." % villager["name"])

func _resource_for_job(job: String) -> String:
	match job:
		"bûcheron":
			return "bois"
		"mineur":
			return "pierre"
		"cueilleur":
			return "nourriture"
		_:
			return "bois"

func _pick_resource_point(resource_name: String) -> Vector2:
	var points: Array = resource_points.get(resource_name, [])
	if points.is_empty():
		return village_position + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
	var point: Vector2 = points.pick_random()
	return point + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

func _can_build_house() -> bool:
	return resource_manager.has_resources(HOUSE_COST) and villagers.size() >= capacity - 1


func _pick_job(is_birth: bool) -> String:
	if not is_birth and not _startup_jobs.is_empty():
		return _startup_jobs.pop_front()
	return str(JOBS.pick_random())

func _next_name() -> String:
	var base_name: String = str(FIRST_NAMES.pick_random())
	var count := int(_used_name_counts.get(base_name, 0))
	_used_name_counts[base_name] = count + 1
	if count == 0:
		return base_name
	return "%s %d" % [base_name, count + 1]

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)

func _random_village_offset() -> Vector2:
	return Vector2(randf_range(-58.0, 58.0), randf_range(-42.0, 42.0))

func _next_house_offset(advance: bool = true) -> Vector2:
	var ring := 1 + int(_house_ring_index / 8)
	var angle := float(_house_ring_index % 8) * TAU / 8.0
	var offset := Vector2(cos(angle), sin(angle)) * (46.0 + ring * 18.0)
	if advance:
		_house_ring_index += 1
	return offset

func _spawn_initial_house() -> void:
	_create_house_visual(village_position + Vector2(-28, -20))

func _create_village_marker() -> void:
	var marker := Node2D.new()
	marker.name = "VillageMarker"
	add_child(marker)
	marker.position = village_position
	var square := Polygon2D.new()
	square.color = Color(0.68, 0.42, 0.18)
	square.polygon = PackedVector2Array([Vector2(-12, -8), Vector2(12, -8), Vector2(12, 8), Vector2(-12, 8)])
	marker.add_child(square)
	var roof := Polygon2D.new()
	roof.color = Color(0.42, 0.16, 0.10)
	roof.polygon = PackedVector2Array([Vector2(-16, -8), Vector2(0, -24), Vector2(16, -8)])
	marker.add_child(roof)
	var label := Label.new()
	label.text = VILLAGE_NAME
	label.position = Vector2(-38, -48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	marker.add_child(label)

func _create_house_visual(house_position: Vector2) -> void:
	var house := Node2D.new()
	house.name = "Maison%d" % _house_count
	add_child(house)
	house.position = house_position
	var wall := Polygon2D.new()
	wall.color = Color(0.75, 0.55, 0.34)
	wall.polygon = PackedVector2Array([Vector2(-10, -4), Vector2(10, -4), Vector2(10, 12), Vector2(-10, 12)])
	house.add_child(wall)
	var roof := Polygon2D.new()
	roof.color = Color(0.50, 0.12, 0.08)
	roof.polygon = PackedVector2Array([Vector2(-14, -4), Vector2(0, -18), Vector2(14, -4)])
	house.add_child(roof)

func _create_villager_visual(villager_name: String, job: String) -> Node2D:
	var body := Node2D.new()
	body.name = villager_name
	add_child(body)
	var shape := Polygon2D.new()
	shape.color = _job_color(job)
	shape.polygon = PackedVector2Array([Vector2(0, -8), Vector2(7, 6), Vector2(-7, 6)])
	body.add_child(shape)
	var label := Label.new()
	label.text = "%s\n%s" % [villager_name, job]
	label.position = Vector2(-24, 8)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	body.add_child(label)
	return body

func _job_color(job: String) -> Color:
	match job:
		"bûcheron":
			return Color(0.19, 0.55, 0.20)
		"mineur":
			return Color(0.46, 0.47, 0.50)
		"cueilleur":
			return Color(0.86, 0.52, 0.18)
		_:
			return Color(0.32, 0.58, 0.91)

func _article_for(resource_name: String) -> String:
	if resource_name == "nourriture":
		return "de la"
	return "du"
