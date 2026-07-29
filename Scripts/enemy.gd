extends CharacterBody3D

@export var moveSpeed := 6.0
@export var acceleration := 6.0
@export var flying := true
@export var hoverHeight := 4.0
@export var ringRadius := 8.0
@export var separationRadius := 2.5
@export var attackRange := 6.0
@export var bobAmount := 0.8
@export var attackPriority := 1.0
@export var clusterManager : Node3D
@export var health = 100

@onready var up = $up
@onready var dwn = $dwn
@onready var forward = $forward
@onready var backward = $backward
@onready var right = $right
@onready var left = $left

func _ready() -> void:
	clusterManager._register(self)

func _damage(amount : int) -> void:
	health -= amount
	if health <= 0:
		clusterManager._unRegister(self)
		queue_free()
