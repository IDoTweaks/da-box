extends Node3D
@export var player : CharacterBody3D
@export var shotgunManager : Node3D
@export var bigBoyMult := 1.25
@export var titanMult := 1.6

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("upgradeManager")

func _bigBoyUpgrade():
	player._setSize(player.size * bigBoyMult)
	return "increases size by 25%"

func _titanUpgrade():
	player._setSize(player.size * titanMult)
	return "increases size by 60%"

func _noop():
	pass

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
