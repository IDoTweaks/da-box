extends Node3D

@export var flashEnergy := 9.0
@export var flashTime := 0.35
@export var lifeTime := 2.6

var size := 1.0

@onready var fireball = $Fireball
@onready var sparks = $Sparks
@onready var smoke = $Smoke
@onready var flash = $Flash

func _ready() -> void:
	scale = Vector3.ONE * size
	flash.omni_range *= size
	flash.light_energy = flashEnergy * size
	fireball.emitting = true
	sparks.emitting = true
	smoke.emitting = true
	var tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, flashTime).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(lifeTime).timeout
	queue_free()
