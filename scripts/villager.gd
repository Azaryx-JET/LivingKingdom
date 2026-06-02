extends Node2D

# Habitant autonome : un sprite Tiny Town visible se promène autour du village.

const VILLAGER_TEXTURE := preload("res://assets/tiny_town/objects/villager.png")
const MIN_SPEED := 28.0
const MAX_SPEED := 46.0
const ARRIVAL_DISTANCE := 3.0

var citizen_name := "Habitant"
var movement_area := Rect2(Vector2.ZERO, Vector2(1.0, 1.0))
var target_position := Vector2.ZERO
var speed := 36.0
var wait_time := 0.0
var sprite: Sprite2D
var name_label: Label

func setup(new_name: String, new_movement_area: Rect2, start_position: Vector2) -> void:
	citizen_name = new_name
	movement_area = new_movement_area
	position = start_position
	speed = randf_range(MIN_SPEED, MAX_SPEED)
	_build_visual()
	_pick_new_target()

func _process(delta: float) -> void:
	if wait_time > 0.0:
		wait_time -= delta
		return

	var direction := target_position - position
	if direction.length() <= ARRIVAL_DISTANCE:
		_pick_new_target()
		return

	position += direction.normalized() * speed * delta
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

func _build_visual() -> void:
	# Le sprite est agrandi pour rester lisible avec la caméra dézoomée.
	sprite = Sprite2D.new()
	sprite.texture = VILLAGER_TEXTURE
	sprite.scale = Vector2(1.8, 1.8)
	add_child(sprite)

	name_label = Label.new()
	name_label.text = citizen_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate = Color(0.08, 0.05, 0.03)
	name_label.position = Vector2(-56.0, -34.0)
	name_label.size = Vector2(112.0, 18.0)
	add_child(name_label)

func _pick_new_target() -> void:
	target_position = Vector2(
		randf_range(movement_area.position.x, movement_area.end.x),
		randf_range(movement_area.position.y, movement_area.end.y)
	)
	wait_time = randf_range(0.15, 0.8)

