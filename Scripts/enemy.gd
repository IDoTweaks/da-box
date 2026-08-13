extends CharacterBody3D

var maxHealth
var dead := false
var healthBar = null
var healthFill = null

@export var level := 3
@export var moveSpeed := 6.0
@export var acceleration := 6.0
@export var flying := true
@export var hoverHeight := 4.0
@export var ringRadius := 8.0
@export var seperationRadius := 2.5
@export var attackRange := 6.0
@export var bobAmount := 0.8
@export var attackPriority := 1.0
@export var hitRadius := .8
@export var barHeight := .72
@export var clusterManager : Node3D
@export var health = 100

@onready var up = $up
@onready var dwn = $dwn
@onready var forward = $forward
@onready var backward = $backward
@onready var right = $right
@onready var left = $left
@onready var rocket = preload("res://Objects/rocket.tscn")
@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")
@onready var healthBarScene = preload("res://Objects/healthBar.tscn")
@onready var rocketSpawn = $launchPoint

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
	vfx.size = .6
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _shootRocket(targ):
	var temp = rocket.instantiate()
	get_tree().current_scene.add_child(temp)
	temp._launch(rocketSpawn.global_position, targ.global_position)

func _telegraph(duration):
	#add here a charge sound
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
