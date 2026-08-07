extends Node3D
@export var player : CharacterBody3D
@export var shotgunManager : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("upgradeManager")

func _bigBoyUpgrade():
	player._setSize(player.size * 1.25)
	return "increases size by 25%"

func _titanUpgrade():
	player._setSize(player.size * 1.6)
	return "increases size by 60%"

func _birthControlUpgrade():
	player.birthControl = true
	return "lets you control how pregenant you are using the mouse wheel"

func _noop():
	pass

func _astronautUpgrade():
	player.gravityMult *= .5
	return "decreases your gravity by 50%"

func _punisherUpgrade():
	shotgunManager.dmg *= 1.5
	return "increases damage by 50%"

func _rugUpgrade():
	player.kbMult *= 1.5
	return "increases knockback by 50%"

func _triggerFingerUpgrade():
	player._reduceCd(.75)
	return "reduces your shotgun cooldown by 25%"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
