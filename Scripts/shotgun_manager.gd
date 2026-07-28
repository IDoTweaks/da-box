extends Node3D

@onready var raysManager = $rays
@export var bullets: int
@export var spread : float
@export var reach : float
@export var dmg: int
@export var start : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raysManager.bullets = bullets
	raysManager.reach = reach
	raysManager.spread = spread
	raysManager._createRays()
	raysManager._randomizeRays()

func _shoot():
	var rays = raysManager.rays
	for ray : RayCast3D in rays:
		ray.force_raycast_update()
		ray.start = start.global_position
		ray._summonBullet()
		if !ray.is_colliding():
			continue
		var hitObj = ray.get_collider()
		if hitObj.has_method("_damage"):
			hitObj._damage(dmg)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
