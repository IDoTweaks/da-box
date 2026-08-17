extends Node3D

@export var bullets := 1
@export var spread := 1.5
@export var coreBias := 1.0
@export var dmg := 25.0
@export var speed := 45.0
@export var bulletGravity := 25.0
@export var bounces := 0
@export var bulletLife := 10.0
@export var bulletSize := 1.0
@export var velocityDmg := 0.0
@export var player : CharacterBody3D
@export var recoil := 20.0
@export var start : Node3D

var bulletManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _shoot(aimPoint : Vector3):
	if bulletManager == null:
		bulletManager = get_tree().get_first_node_in_group("playerBullets")
	var origin = start.global_position
	var baseDir = aimPoint - origin
	if baseDir.length_squared() < .0001:
		baseDir = -global_transform.basis.z
	baseDir = baseDir.normalized()
	var right = global_transform.basis.x
	var up = global_transform.basis.y
	var maxAngle = deg_to_rad(spread)
	var shotDmg = dmg
	if velocityDmg > 0 and player:
		shotDmg += player.velocity.length() * velocityDmg
	for i in bullets:
		var angle = randf() * TAU
		var dist = maxAngle * pow(randf(), coreBias)
		var dir = (baseDir + right * cos(angle) * dist + up * dist * sin(angle)).normalized()
		bulletManager._spawn(origin, dir * speed,shotDmg,bulletGravity,bulletLife,bounces,bulletSize)
		
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
