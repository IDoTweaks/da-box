extends CanvasLayer
var health = 100

@onready var healthBar = $ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update()

func _update():
	healthBar.value = health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
