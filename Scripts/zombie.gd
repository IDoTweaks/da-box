extends CharacterBody3D

var maxHealth
var dead := false

@export var moveSpeed := 4.5
@export var acceleration := 10.0
@export var turnSpeed := 8.0
@export var flying := false
@export var ringRadius := 4.0
@export var seperationRadius := 1.8
@export var seperationStrength := 4.0
@export var waypointToTolerance := .6
@export var attackRange := 1.8
@export var attackPriority := 1.0
@export var fireCooldown := 1.5
@export var fireRange := 2.5
@export var windUp := .45
@export var needsLineOfSight := false
@export var dmg := 12
@export var clusterManager : Node3D
@export var health = 150

@onready var healthBar = $healthBar
@onready var healthFill = $healthBar/fill
@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")

func _ready() -> void:
	maxHealth = health
	healthBar.visible = false
	_updateHealthBar()
	clusterManager._register(self)

func _damage(amount : int) -> void:
	if dead:
		return
	health -= amount
	_updateHealthBar()
	if health <= 0:
		_die()

func _die():
	if dead:
		return
	dead = true
	_spawnVfx()
	clusterManager._unRegister(self)
	queue_free()

func _spawnVfx():
	var vfx = explosionVfx.instantiate()
	vfx.size = .5
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _attack(targ):
	if global_position.distance_to(targ.global_position) > fireRange:
		return
	if targ.has_method("_damage"):
		targ._damage(dmg)

func _telegraph(duration):
	#add here a growl
	pass

func _showHealthBar():
	healthBar.visible = true

func _hideHealthBar():
	healthBar.visible = false

func _updateHealthBar():
	var ratio = maxf(float(health) / maxHealth, .001)
	var w = healthFill.mesh.size.x
	healthFill.scale.x = ratio
	healthFill.position.x = -(w * (1 - ratio)) / 2

func _process(delta: float) -> void:
	if not healthBar.visible:
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	healthBar.look_at(healthBar.global_position + (healthBar.global_position - cam.global_position))
