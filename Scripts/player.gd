extends CharacterBody3D

const MOUSE_SENSITIVITY = 0.003
const SPEED = 5
const DEAFULTFOV = 75.0

var forcesX : Array
var forcesY : Array
var forcesZ : Array
var forceTime : Array
var forceDecay : Array
var onCd = false
var inAir = false

@export var explosionFallOff := 1.5
@export var deafualtShotgunForce := 25.0
@export var deafultTime := 1
@export var friction := 10.0
@export var maxSpeed := 40.0

@onready var shotgunSfx =$shotgunSfx
@onready var landSfx = $landSfx

@onready var feet = $feet
@onready var shotgunEnd = $playerCam/shotGun/shotgunEnd
@onready var shotgun = $playerCam/shotGun
@onready var ray = $playerCam/RayCast3D
@onready var playerCam: Camera3D = $playerCam
@onready var shotgunCd = $shotgunCd
@onready var rayEnd = $playerCam/rayEnd

@onready var shotgunFireParticle = preload("res://particles/shotgunFireParticle.tscn")
@onready var landingParticles = preload("res://particles/landingParticles.tscn")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	playerCam.fov = DEAFULTFOV


func _applyForceFromPoint(point, force, time,decay = 0):
	#this math is brought to you by: gemini but i coded it:D
	var unWeightedX = abs(global_position.x - point.x)
	var unWeightedY = abs(global_position.y - point.y)
	var unWeightedZ = abs(global_position.z - point.z)
	var length = sqrt((unWeightedX * unWeightedX) + (unWeightedY * unWeightedY) + (unWeightedZ * unWeightedZ))
	if length == 0: 
		return
	forceTime.append(time)
	forceDecay.append(decay)
	var weightedX = unWeightedX / length
	var weightedY = unWeightedY / length
	var weightedZ = unWeightedZ / length
	force -= (global_position.distance_to(point) * explosionFallOff)
	if force < 5:
		force = 5
	forcesX.append(sign(global_position.x - point.x) * weightedX * force)
	forcesZ.append(sign(global_position.z - point.z) * weightedZ * force)
	forcesY.append(sign(global_position.y - point.y) * weightedY * force)

func _applyForceToPoint(point, force, time,decay = 0):
	#this math is brought to you by: gemini but i coded it:D
	var unWeightedX = abs(point.x-global_position.x)
	var unWeightedY = abs(point.y-global_position.y )
	var unWeightedZ = abs(point.z-global_position.z)
	var length = sqrt((unWeightedX * unWeightedX) + (unWeightedY * unWeightedY) + (unWeightedZ * unWeightedZ))
	if length == 0: 
		return
	var weightedX = unWeightedX / length
	var weightedY = unWeightedY / length
	var weightedZ = unWeightedZ / length
	forceTime.append(time)
	forceDecay.append(decay)
	
	forcesX.append(sign(point.x-global_position.x) * weightedX * force)
	forcesZ.append(sign(point.z-global_position.z) * weightedZ * force)
	forcesY.append(sign(point.y-global_position.y) * weightedY * force)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		playerCam.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		playerCam.rotation.x = clamp(playerCam.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _fireShotgun() -> void:
	ray.force_raycast_update()
	var point : Vector3
	if ray.is_colliding():
		point = ray.get_collision_point()
	else:
		point = rayEnd.global_position
	var tween = create_tween()
	tween.tween_property(playerCam,"fov",DEAFULTFOV + 5,0.1)
	tween.tween_property(playerCam,"fov",DEAFULTFOV,0.1)
	
	shotgunSfx.play()
	
	var temp = shotgunFireParticle.instantiate()
	add_child(temp)
	temp.global_position = shotgunEnd.global_position
	temp.emitting = true
	
	_applyImpulse(point,global_position - point, deafualtShotgunForce)

func _applyForceDecay(i,delta):
	forcesX[i] = move_toward(forcesX[i], 0, forceDecay[i] * delta)
	forcesY[i] = move_toward(forcesY[i], 0, forceDecay[i] * delta)
	forcesZ[i] = move_toward(forcesZ[i], 0, forceDecay[i] * delta)
	

func _applyImpulse(point,dir : Vector3, strength):
	if dir.length() == 0:
		return
	var n = dir.normalized()
	var opp = velocity.dot(n)#because opposites are my opponents!
	if opp < 0:
		velocity -= n * opp
	strength -= (global_position.distance_to(point) * explosionFallOff)
	strength = max(strength,5.0)
	velocity += n * strength
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("leftClick") and not onCd:
		_fireShotgun()
		onCd = true
		shotgunCd.start()
	
	if inAir and is_on_floor():
		landSfx.play()
		var temp = landingParticles.instantiate()
		add_child(temp)
		temp.global_position = shotgunEnd.global_position
		temp.emitting = true
	
	if not is_on_floor():
		velocity += get_gravity() * delta
		inAir = true
	else:
		inAir = false
		#this part is just friction you can play with it and the game feels a lot different
		velocity.x = move_toward(velocity.x, 0,friction * delta)
		velocity.z = move_toward(velocity.z, 0,friction * delta)
	
	#apply forces
	for i in range(forceTime.size() - 1,-1,-1):
		if forceTime[i] > 0:
			forceTime[i] -= delta
			velocity.x += forcesX[i] * delta
			velocity.z += forcesZ[i] * delta
			velocity.y += forcesY[i] * delta
			_applyForceDecay(i,delta)
		else:
			forceTime.remove_at(i)
			forcesX.remove_at(i)
			forcesZ.remove_at(i)
			forcesY.remove_at(i)
			forceDecay.remove_at(i)
	
	velocity = velocity.limit_length(maxSpeed)
	move_and_slide()


func _on_shotgun_cd_timeout() -> void:
	onCd = false
