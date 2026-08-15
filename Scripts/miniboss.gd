extends CharacterBody3D

var maxHealth
var dead := false
var healthBar
var healthFill

@export var level := 6
@export var moveSpeed := 3.2
@export var acceleration := 8.0
@export var turnSpeed := 3.5
@export var flying := false
@export var hoverHeight := 0.0
@export var ringRadius := 4.0
@export var seperationRadius := 3.0
@export var seperationStrength := 2.0
@export var waypointToTolerance := 1.0
@export var attackRange := 3.5
@export var attackPriority := 50.0
@export var fireCooldown := 2.0
@export var fireRange := 4.5
@export var windUp := .6
@export var needsLineOfSight := false
@export var dmg := 25
@export var hitRadius := 1.9
@export var hitHeight := 2.2
@export var barHeight := 5.0
@export var clusterManager : Node3D
@export var health = 800

@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")
@onready var healthBarScene = preload("res://Objects/healthBar.tscn")

func _ready() -> void:
	set_process(false)
	maxHealth = health
	clusterManager._register(self)

func _damage(amount) -> void:
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
	clusterManager._despawn(self)

func _reset():
	dead = false
	health = maxHealth
	velocity = Vector3.ZERO
	_hideHealthBar()
	_updateHealthBar()

func _spawnVfx():
	var vfx = explosionVfx.instantiate()
	vfx.size = 2.0
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _attack(targ):
	var off = targ.global_position - global_position
	off.y = 0
	if off.length() > fireRange + clusterManager.targetRadius:
		return
	if targ.has_method("_damage"):
		targ._damage(dmg)

func _telegraph(duration):
	#add here a growl
	pass

func _showHealthBar():
	if healthBar == null:
		healthBar = healthBarScene.instantiate()
		add_child(healthBar)
		healthBar.position.y = barHeight
		healthFill = healthBar.get_node("fill")
		_updateHealthBar()
	healthBar.visible = true
	set_process(true)

func _hideHealthBar():
	if healthBar != null:
		healthBar.visible = false
	set_process(false)

func _updateHealthBar():
	if healthFill == null:
		return
	var ratio = maxf(float(health) / maxHealth, .001)
	var w = healthFill.mesh.size.x
	healthFill.scale.x = ratio
	healthFill.position.x = -(w * (1 - ratio)) / 2

func _process(delta: float) -> void:
	if healthBar == null or not healthBar.visible:
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	healthBar.look_at(healthBar.global_position + (healthBar.global_position - cam.global_position))
