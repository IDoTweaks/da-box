extends Node3D

@onready var raysManager = $rays
@export var bullets: int
@export var spread : float
@export var reach : float
@export var dmg: int
@export var hitMask : int
@export var coreBias : float
@export var start : Node3D

var cluster = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raysManager.bullets = bullets
	raysManager.reach = reach
	raysManager.spread = spread
	raysManager.hitMask = hitMask
	raysManager.coreBias = coreBias
	raysManager._createRays()
	raysManager._randomizeRays()

func _shoot():
	if cluster == null:
		cluster = get_tree().get_first_node_in_group("clusterManager")
	raysManager._randomizeRays()
	var hits = 0
	var rays = raysManager.rays
	for ray : RayCast3D in rays:
		ray.force_raycast_update()
		ray.start = start.global_position
		var blocked = ray.is_colliding()
		var from = ray.global_position
		var end = ray.to_global(ray.target_position)
		var dir = (end - from).normalized()
		var stop = ray.get_collision_point() if blocked else end
		var done = false
		if blocked:
			var hitObj = ray.get_collider()
			if hitObj.has_method("_damage"):
				hitObj._damage(dmg)
				hits += 1
				done = true
		if not done and cluster != null:
			var t = cluster._pelletHit(from, dir, from.distance_to(stop), dmg)
			if t > 0:
				hits += 1
				stop = from + dir * t
		ray._summonBullet(stop)
	return hits


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
