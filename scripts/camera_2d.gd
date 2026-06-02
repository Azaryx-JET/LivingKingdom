extends Camera2D

# Caméra existante conservée : ZQSD/WASD déplacent la vue sur la grande carte.

@export var speed := 700.0

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	var direction := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	position += direction * speed * delta
