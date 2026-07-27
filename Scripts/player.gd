extends CharacterBody3D

const MOUSE_SENSITIVITY = 0.003
const SPEED = 5
var forcesX : Array
var forcesY : Array
var forcesZ : Array
var forceTime : Array

@onready var player_cam: Camera3D = $playerCam

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _applyForceFromPoint(point, force, time):
	#this math is brought to you by: gemini but i coded it:D
	forceTime.append(time)
	var unWeightedX = abs(global_position.x - point.x)
	var unWeightedY = abs(global_position.y - point.y)
	var unWeightedZ = abs(global_position.z - point.z)
	var length = sqrt((unWeightedX * unWeightedX) + (unWeightedY * unWeightedY) + (unWeightedZ * unWeightedZ))
	if length == 0: 
		return
	var weightedX = unWeightedX / length
	var weightedY = unWeightedY / length
	var weightedZ = unWeightedZ / length
	
	forcesX.append(sign(global_position.x - point.x) * weightedX * force)
	forcesZ.append(sign(global_position.z - point.z) * weightedZ * force)
	forcesY.append(sign(global_position.y - point.y) * weightedY * force)

func _applyForceToPoint(point, force, time):
	#this math is brought to you by: gemini but i coded it:D
	forceTime.append(time)
	var unWeightedX = abs(point.x-global_position.x)
	var unWeightedY = abs(point.y-global_position.y )
	var unWeightedZ = abs(point.z-global_position.z)
	var length = sqrt((unWeightedX * unWeightedX) + (unWeightedY * unWeightedY) + (unWeightedZ * unWeightedZ))
	if length == 0: 
		return
	var weightedX = unWeightedX / length
	var weightedY = unWeightedY / length
	var weightedZ = unWeightedZ / length
	
	forcesX.append(sign(point.x-global_position.x) * weightedX * force)
	forcesZ.append(sign(point.z-global_position.z) * weightedZ * force)
	forcesY.append(sign(point.y-global_position.y) * weightedY * force)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		player_cam.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		player_cam.rotation.x = clamp(player_cam.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
