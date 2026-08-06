extends CharacterBody3D

var maxHealth
var dead := false
var healthBar = null
var healthFill = null

@export var level := 4
@export var moveSpeed := 9.0
@export var acceleration := 30.0
@export var turnSpeed := 6.0
@export var flying := true
@export var diving := true
@export var hoverHeight := 12.0
@export var ringRadius := 10.0
@export var diveSpeed := 26.0
@export var climbSpeed := 14.0
@export var diveRest := 1.5
@export var seperationRadius := 2.0
@export var seperationStrength := 4.0
@export var attackRange := 2.5
@export var avoidStrength := 2.0
@export var fireRange := 4.0
@export var dmg := 5
@export var hitRadius := 1.0
@export var hitHeight := 0.0
@export var barHeight := .6
@export var clusterManager : Node3D
@export var health = 80

@onready var up = $up
@onready var dwn = $dwn
@onready var forward = $forward
@onready var backward = $backward
@onready var right = $right
@onready var left = $left
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
	vfx.size = .5
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _attack(targ):
	var off = targ.global_position - global_position
	if off.length() > fireRange + clusterManager.targetRadius:
		return
	if targ.has_method("_damage"):
		targ._damage(dmg)

func _telegraph(duration):
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
