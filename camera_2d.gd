extends Camera2D

@export var speed := 700.0

func _ready():
	make_current()

func _process(delta):
	var direction := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	position += direction * speed * delta
