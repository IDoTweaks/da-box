extends CanvasLayer
var health = 100

@export var maxHealth := 100.0

@onready var waveLabel = $waveLabel
@onready var healthBar = $healthBar
@onready var healthValue = $healthBar/value
@onready var hitMarker = $hitMarker
@onready var debugLabel = $debugLabel

var waves = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update()

func _update():
	healthBar.max_value = maxHealth
	healthBar.value = health
	healthValue.text = str(int(round(max(health,0.0))))

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
	if waves == null:
		waves = get_tree().get_first_node_in_group("waveManager")
		if waves == null:
			return
	debugLabel.text = str(Engine.get_frames_per_second()) + " fps\nwave " + str(waves.waveNumber)
	waveLabel.text = "wave " + str(waves.waveNumber) + "\n" + str(mini(waves._waveKills(),waves.waveQuota)) + " / " + str(waves.waveQuota)
