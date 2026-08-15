extends CanvasLayer

@export var fadeTime := .5

var waves
var cluster
var startTime := 0

@onready var dim = $ColorRect
@onready var stats = $ColorRect/stats

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("deathScreen")
	startTime = Time.get_ticks_msec()

func _open():
	if visible:
		return
	stats.text = _statsText()
	dim.modulate.a = 0.0
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var tween = create_tween()
	tween.tween_property(dim,"modulate:a", 1.0, fadeTime)
	

func _statsText():
	if waves == null:
		waves = get_tree().get_first_node_in_group("waveManager")
	if cluster == null:
		cluster = get_tree().get_first_node_in_group("clusterManager")
	var wave = waves.waveNumber
	var kills = cluster.kills
	var secs = int((Time.get_ticks_msec() - startTime) / 1000.0)
	return "wave " + str(wave) + "\n" + str(kills) + " kills\n" + ("%d:%02d" % [secs / 60, secs % 60]) + " survived" 
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/mainMenu.tscn")
