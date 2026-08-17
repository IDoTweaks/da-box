extends Node3D
@export var player : CharacterBody3D
@export var shotgunManager : Node3D

var roboCount := 0
var robuddies := []
var roboDmgMult := 1.0
var roboRateMult := 1.0
var roboPerce := 0.0

@onready var robuddy = preload("res://Objects/robuddy.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("upgradeManager")

func _robuddyUpgrade():
	var temp = robuddy.instantiate()
	temp.player = player
	get_tree().current_scene.add_child(temp)
	temp.global_position = player.global_position
	temp.angle = roboCount * TAU / 3
	temp.dmg *= roboDmgMult
	temp.fireInterval *= roboRateMult
	temp.perceDmg = roboPerce
	robuddies.append(temp)
	roboCount += 1
	return "i know you are bad at making friends... since i couldnt get a real human to agree to being your friend you get a robot!"

func _bigBoyUpgrade():
	player._setSize(player.size * 1.25)
	return "stop breathing so much! you fucking inflated"

func _advancedCalcuklatingUpgrade():
	roboPerce += .1
	for robo in robuddies:
		robo.perceDmg =roboPerce
	return "your robuddies can now calculate % and they are ADDICTED"

func _goldPlatedUpgrade():
	roboRateMult *= .65
	for robot in robuddies:
		robot.fireInterval *= .65
	return "your robuddies got a hardware grant and decided to stack them to get some gold plated parts"

func _evilAiUpgrade():
	roboDmgMult *= 1.75
	for robot in robuddies:
		robot.dmg *= 1.75
	return "your robots decided to buy lots of fighting books and burn them! but at least they kill better YAYY"

func _titanUpgrade():
	player._setSize(player.size * 1.6)
	return "collosal titan type shit"

func _birthControlUpgrade():
	player.birthControl = true
	return "lets you control how pregenant you are using the mouse wheel"

func _noop():
	pass

func _astronautUpgrade():
	player.gravityMult *= .5
	return "moon gravity enabled!"

func _punisherUpgrade():
	shotgunManager.dmg *= 1.5
	return "JUDGE! JURY! EXECUTIONER!"

func _rugUpgrade():
	player.kbMult *= 1.5
	return "become a rugdoll! except that idk how to use them so just become a punching bag T_T"

func _triggerFingerUpgrade():
	player._reduceCd(.75)
	return "put your cornHub muscle memory into use"

func _heatResistanceUpgrade():
	player.maxSpeed += player.maxSpeed / 5
	return "makes you clothing more heat resistant allowing you to achive higher speeds"

func _ammoDrop():
	shotgunManager.bullets += randi_range(1,3)
	shotgunManager.spread += 1.5
	return "get foreign aid but from one guy and his almost empty stock of bullets"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
