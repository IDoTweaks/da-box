extends Node3D

@export var bullets: int
@export var spread : float
@export var reach : float
@export var hitMask : int

@onready var ray = $RayCast3D
var rays

func _randomizeRays():
	for raycast : RayCast3D in rays:
		raycast.target_position.x += randf_range(-(spread / 4),(spread / 4))
		raycast.target_position.y += randf_range(-(spread / 4),(spread / 4))

func _ready() -> void:
	rays = [ray]

func _createRays():
	rays = [ray]
	ray.target_position.z = -reach
	ray.collision_mask = hitMask
	for i in range(bullets - 1):
		var newRay = ray.duplicate()
		newRay.target_position.z = -reach
		add_child(newRay)
		rays.append(newRay)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
