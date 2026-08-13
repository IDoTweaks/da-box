extends Control

#hehehehe butts here
@onready var playButt = $VBoxContainer/playButton
@onready var quitButt = $VBoxContainer/quitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
