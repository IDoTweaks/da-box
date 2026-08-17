extends CharacterBody3D

var maxHealth
var dead := false
var healthBar
var healthFill
var warnTween
var animState := ""
var bones

@onready var slamWarn = $slamWarn
@onready var chargeWarn = $chargeWarn
@onready var boneWarn = $boneWarn
@onready var throwPoint = $throwPoint

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
@export var health = 1000

@export var boneRange := 34.0
@export var boneMinRange := 10.0
@export var boneCooldown := 6.0
@export var boneWindUp := .85
@export var boneRecover := .9
@export var boneCount := 7
@export var boneSpread := 24.0
@export var boneSpeed := 26.0
@export var boneArc := 6.0
@export var boneSpeedJitter := .12
@export var boneDmg := 16.0
@export var boneKnockback := 24.0
@export var boneOriginJitter := .35

@export var idleAnim := "Dracula1_MeleeEnemy_Idle"
@export var walkAnim := "Dracula1_MeleeEnemy_Walk"
@export var chargeWindAnim := "Dracula1_MeleeEnemy_Jump_Charge"
@export var chargeAnim := "Dracula1_MeleeEnemy_Attack_charge_Loop"
@export var slamWindAnim : = "Dracula1_MeleeEnemy_Attack_Swing_Right"
@export var throwAnim := "Dracula1_MeleeEnemy_Attack_Swing_left"
@export var recoverAnim := "Dracula1_MeleeEnemy_Attack_recover_Loop"
@export var animBlend := .15
@export var loopingAnims : Array[String] = ["Dracula1_MeleeEnemy_Idle", "Dracula1_MeleeEnemy_Walk",
"Dracula1_MeleeEnemy_Attack_charge_Loop", "Dracula1_MeleeEnemy_Attack_recover_Loop", "Dracula1_MeleeEnemy_Run_Loop"]

@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")
@onready var healthBarScene = preload("res://Objects/healthBar.tscn")
@onready var anim : AnimationPlayer = $Sketchfab_Scene/AnimationPlayer

func _ready() -> void:
	set_process(false)
	maxHealth = health
	_setUpAnims()
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
	animState = ""
	_play(idleAnim)
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
	

func _throwBones(targ):
	if dead:
		return
	_hideWarns()
	if bones == null:
		bones = get_tree().get_first_node_in_group("boneManager")
	var origin = throwPoint.global_position
	var flat = targ.global_position - origin
	flat.y = 0
	if flat.length_squared() < .0001:
		flat = -global_transform.basis.z
	flat = flat.normalized()
	var half = deg_to_rad(boneSpread)
	var side = flat.cross(Vector3.UP)
	for i in boneCount:
		var t = 0.0 if boneCount == 1 else float(i) / float(boneCount - 1) * 2 - 1
		var dir = flat.rotated(Vector3.UP, t * half)
		var speed = boneSpeed * (1 + randf_range(-boneSpeedJitter, boneSpeedJitter))
		var vel = dir * speed + Vector3.UP * boneArc
		bones._spawn(origin + side * t * boneOriginJitter, vel,boneDmg,boneKnockback)
		
	
	
	


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

func _telegraphBones(duration):
	var width = 2 * boneRange * tan(deg_to_rad(boneSpread))
	boneWarn.position = Vector3(0,.07, boneRange * .5)
	boneWarn.scale = Vector3(width / 3.4,1,boneRange)
	
	



func _hideWarns():
	if warnTween != null and warnTween.is_valid():
		warnTween.kill()
	warnTween = null
	slamWarn.visible = false
	chargeWarn.visible = false
	boneWarn.visible = false

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

func _setUpAnims():
	if anim == null:
		return
	for name in anim.get_animation_list():
		var a = anim.get_animation(name)
		a.loop_mode = Animation.LOOP_LINEAR if name in loopingAnims else Animation.LOOP_NONE
	_play(idleAnim)
	

func _play(name, fitTime := 0.0):
	if anim == null or name == "" or not anim.has_animation(name) or (anim.current_animation == name and anim.is_playing()):
		return
	var speed := 1.0
	if fitTime> .05:
		var len = anim.get_animation(name).length
		if len > .01:
			speed = len / fitTime
	anim.play(name, animBlend, speed)
	

func _onState(state):
	animState = state
	if "attack" == state:
		_play(walkAnim)
	elif state == "chargeWind":
		_play(chargeWindAnim, chargeWindUp)
	elif state == "charge":
		_play(chargeAnim)
	elif state == "slamWind":
		_play(slamWindAnim, slamWindUp)
	elif state == "boneWind":
		_play(throwAnim, boneWindUp)
	else:
		_play(recoverAnim)
	
