extends Camera2D

@export var speed := 700.0

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	var direction := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	position += direction * speed * delta
