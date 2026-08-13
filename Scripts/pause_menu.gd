extends CanvasLayer

var cards = null

#ok you caught me calling them butts is confusing but i like it
@onready var resumeButt =  $ColorRect/VBoxContainer/resumeButton
@onready var mainMenuButt =  $ColorRect/VBoxContainer/mainMenuButton
@onready var quitBUtt = $ColorRect/VBoxContainer/quitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _cardsOpen():
		return
	if visible:
		_on_resume_button_pressed()
		return
	_open()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _open():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _on_resume_button_pressed() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/mainMenu.tscn")

func _cardsOpen():
	if cards == null:
		cards = get_tree().get_first_node_in_group("cardScreen")
	return cards != null and cards.visible

func _on_quit_button_pressed() -> void:
	get_tree().quit()
