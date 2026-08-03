extends Node3D
@export var player : CharacterBody3D
@export var shotgunManager : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _astronautUpgrade():
	player.grvity *= 1.5
	return "decreases gravity by 50%"

func _punisherUpgrade():
	shotgunManager.dmg *= 1.5
	return "increases damage by 50%"

func _rugUpgrade():
	player.kbMult *= 1.5
	return "increases knockback by 50%"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
