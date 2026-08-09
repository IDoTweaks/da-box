extends Node3D

var cluster = null
var fireTimer =0.0
var angle = 0.0

@export var player : CharacterBody3D
@export var followHeight := 2.2
@export var followRadius := 1.8
@export var followSpeed := 8.0
@export var orbitSpeed := 1.5
@export var fireInterval := 1.0
@export var fireRange := 25.0
@export var dmg := 25.0
@export var perceDmg := 0.0

@onready var bullet = preload("res://Objects/bullet.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _tracer(point):
	var temp = bullet.instantiate()
	get_tree().current_scene.add_child(temp)
	temp.global_position = global_position
	if global_position.distance_to(point) > .01:
		temp.look_at(point)
	var t = create_tween()
	t.tween_property(temp,"global_position",point,.08)
	t.tween_callback(temp.queue_free)

func _hitDamage(maxHealth):
	if perceDmg == 0:
		return dmg
	return maxHealth * perceDmg

func _fire():
	var body = cluster._nearestBody(global_position,fireRange)
	if body != null:
		_tracer(body.global_position)
		body._damage(_hitDamage(body.maxHealth))
		return
	var idx = cluster._nearestVirtual(global_position, fireRange)
	if idx == -1:
		return
	_tracer(cluster.virtPos[idx])
	cluster._damageVirtual(idx,_hitDamage(cluster.virtMax[idx]))
	


func _hover(delta):
	angle += delta * orbitSpeed
	var goal = player.global_position
	goal.x += cos(angle) *followRadius
	goal.z += sin(angle) * followRadius
	goal.y += followHeight
	global_position = global_position.lerp(goal, clamp(followSpeed * delta,0,1))


func _physics_process(delta: float) -> void:
	if cluster == null:
		cluster = get_tree().get_first_node_in_group("clusterManager")
	_hover(delta)
	fireTimer -= delta
	if fireTimer >0:
		return
	fireTimer = fireInterval
	_fire()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
