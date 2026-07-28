extends RayCast3D

@onready var bullet = preload("res://Objects/bullet.tscn")
var start

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _summonBullet():
	var end = to_global(target_position)
	var newBullet = bullet.instantiate()
	get_tree().current_scene.add_child(newBullet)
	newBullet.global_position = start
	newBullet.look_at(end)
	var t = create_tween()
	t.tween_property(newBullet,"global_position",end,.1)
	t.tween_callback(newBullet.queue_free)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
