extends Node3D

@export var bullets: int
@export var spread : float
@export var reach : float
@export var hitMask : int
@export var coreBias : float

@onready var ray = $RayCast3D
var rays

func _randomizeRays():
	for raycast : RayCast3D in rays:
		var angle = randf() * TAU
		var dist = (spread / 4) * pow(randf(),coreBias)
		raycast.target_position.x = cos(angle) * dist
		raycast.target_position.y = sin(angle) * dist
		raycast.target_position.z = -reach

func _ready() -> void:
	rays = [ray]

func _createRays():
	for r in rays:
		if r != ray:
			r.queue_free()
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
