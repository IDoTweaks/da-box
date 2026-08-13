extends Area3D

var targetPos : Vector3
var exploded := false
var direction

@export var speed := 30.0
@export var explosionStrength := 22.0
@export var explosionRadius := 5.0
@export var upBias := 0.5

@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")

func _ready() -> void:
	body_entered.connect(_onHit)

func _physics_process(delta : float) -> void:
	global_position = global_position.move_toward(targetPos, speed * delta)
	if global_position.distance_to(targetPos) < 1:
		_explode()

func _onHit(body) -> void:
	_explode()

func _launch(from, to):
	global_position = from
	targetPos = to
	var dir = to - from
	direction = dir.normalized() if dir.length() > .01 else Vector3.FORWARD
	if dir.length() > .01:
		var up = Vector3.UP if abs(dir.normalized().y) < .99 else Vector3.FORWARD
		look_at(to, up)

func _explode() -> void:
	if exploded:
		return
	exploded = true
	_spawnVfx()
	for body in get_tree().get_nodes_in_group("blastable"):
		var offset = body.global_position - global_position
		var dist = offset.length()
		if dist > explosionRadius:
			continue
		var dir = (offset.normalized() + Vector3.UP * upBias).normalized() if dist > 0.5 else direction
		var falloff = 1.0 - (dist/explosionRadius)
		if body.has_method("_applyImpulse"):
			body._applyImpulse(global_position, dir, explosionStrength * falloff)
		if body.has_method("_explosionDamage"):
			body._explosionDamage(global_position, explosionStrength * falloff)
	queue_free()

func _spawnVfx() -> void:
	var vfx = explosionVfx.instantiate()
	vfx.size = explosionRadius / 5.0
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position
