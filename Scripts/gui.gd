extends CanvasLayer
var health = 100

@onready var healthBar = $ProgressBar
@onready var hitMarker = $hitMarker

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update()

func _update():
	healthBar.value = health

func _hitMarker():
	hitMarker.visible = true
	hitMarker.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(hitMarker,"modulate:a",0.0,.25)
	tween.tween_callback(_hideHitMarker)

func _hideHitMarker():
	hitMarker.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
