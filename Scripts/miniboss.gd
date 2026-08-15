extends CharacterBody3D

var maxHealth
var dead := false
var healthBar
var healthFill
var warnTween

@onready var slamWarn = $slamWarn
@onready var chargeWarn = $chargeWarn

@export var level := 6
@export var isBoss := true

@export var charger := true
@export var chargeRange := 26.0
@export var chargeMinRange := 9.0
@export var chargeSpeed := 20.0
@export var chargeAccel := 80.0
@export var chargeWindUp := .75
@export var chargeTime := 1.4
@export var chargeCooldown = 4.0
@export var chargeHitRange := 3.2
@export var chargeRecover := 1.2
@export var chargeDmg := 30.0
@export var chargeKnockback := 55.0

@export var slamRange := 4.5
@export var slamWindUp := .6525
@export var slamRecover := 1.0
@export var slamCooldown := 5.0
@export var slamRadius := 6.0
@export var slamDmg := 30.0
@export var slamKnockback := 42.0
@export var slamUpBias := .8
@export var warnFadeFrom := .85
@export var warnFadeTo := .25

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
@export var fireRange := 0.0
@export var windUp := .6
@export var needsLineOfSight := false
@export var dmg := 0
@export var hitRadius := 1.2
@export var hitHeight := 2.2
@export var barHeight := 6.0
@export var clusterManager : Node3D
@export var health = 2500

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
	_hideWarns()
	_spawnVfx()
	clusterManager._despawn(self)

func _reset():
	dead = false
	health = maxHealth
	velocity = Vector3.ZERO
	_hideWarns()
	_hideHealthBar()
	_updateHealthBar()

func _spawnVfx(vfxSize := 2.0):
	var vfx = explosionVfx.instantiate()
	vfx.size = vfxSize
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = global_position

func _attack(targ):
	var off = targ.global_position - global_position
	off.y = 0
	if off.length() > fireRange + clusterManager.targetRadius:
		return
	if targ.has_method("_damage"):
		targ._damage(dmg)

func _chargeHit(targ):
	if targ.has_method("_damage"):
		targ._damage(chargeDmg)
	if targ.has_method("_applyImpulse"):
		var dir = targ.global_position - global_position
		dir.y = 0
		if dir.length_squared() < .0001:
			dir = -global_transform.basis.z
		targ._applyImpulse(global_position, (dir.normalized() + Vector3.UP * .35).normalized(), chargeKnockback)
	

func _slam(targ):
	_hideWarns()
	_spawnVfx(slamRadius/4.0)
	var reach = slamRadius + clusterManager.targetRadius
	var offset = targ.global_position - global_position
	if offset.length_squared() > reach * reach:
		return
	if targ.has_method("_explosionDamage"):
		targ._explosionDamage(global_position, slamDmg)
	offset.y = 0
	var flatSqrd = offset.length_squared()
	var dir = offset / sqrt(flatSqrd) if flatSqrd > .25 else Vector3(randf() - .5,0,randf() - .5).normalized()
	targ._applyImpulse(global_position, (dir + Vector3.UP * slamUpBias).normalized(), slamKnockback)
	

func _flashWarn(node, duration):
	if warnTween != null and warnTween.is_valid():
		warnTween.kill()
	node.transparency = warnFadeFrom
	node.visible = true
	warnTween = create_tween()
	warnTween.tween_property(node, "transparency", warnFadeTo, duration)
	warnTween.tween_callback(node.hide)
	

func _telegraphCharge(duration):
	var reach = chargeSpeed * chargeTime
	chargeWarn.position = Vector3(0, .06, reach * .5)
	chargeWarn.scale = Vector3(1,1,reach)
	_flashWarn(chargeWarn, duration)

func _telegraphSlam(duration):
	slamWarn.scale = Vector3(slamRadius,1,slamRadius)
	_flashWarn(slamWarn, duration)

func _hideWarns():
	if warnTween != null and warnTween.is_valid():
		warnTween.kill()
	warnTween = null
	slamWarn.visible = false
	chargeWarn.visible = false

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
