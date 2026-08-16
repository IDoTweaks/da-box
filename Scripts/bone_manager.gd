extends MultiMeshInstance3D

@export var maxBones := 256
@export var gravity := 14.0
@export var hitRadius := 1.15
@export var targetHeight := 1.0
@export var groundY := -.85
@export var lifetime := 6.0
@export var spinSpeed := 9.0

var bonePos : PackedVector3Array
var boneVel : PackedVector3Array
var boneLife : PackedFloat32Array
var boneSpin : PackedFloat32Array
var boneDmg : PackedFloat32Array
var boneKb : PackedFloat32Array
var count := 0
var target
var mm : MultiMesh


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("boneManager")
	bonePos.resize(maxBones)
	boneVel.resize(maxBones)
	boneLife.resize(maxBones)
	boneSpin.resize(maxBones)
	boneDmg.resize(maxBones)
	boneKb.resize(maxBones)
	mm = multimesh
	mm.transform_format =MultiMesh.TRANSFORM_3D
	mm.instance_count = maxBones
	mm.visible_instance_count = 0
	

func _spawn(pos : Vector3,vel : Vector3,dmg,kb):
	if count >= maxBones:
		return
	bonePos[count] = pos
	boneVel[count] = vel
	boneLife[count] = lifetime
	boneSpin[count] = randf() * TAU
	boneDmg[count] = dmg
	boneKb[count] = kb
	count +=1
	

func _swapOut(i):
	count -= 1
	bonePos[i] = bonePos[count]
	boneVel[i] = boneVel[count]
	boneLife[i] = boneLife[count]
	boneSpin[i] = boneSpin[count]
	boneDmg[i] = boneDmg[count]
	boneKb[i] = boneKb[count]

func _physics_process(delta: float) -> void:
	if count == 0:
		if mm.visible_instance_count != 0:
			mm.visible_instance_count = 0
		return
	if target == null:
		target = get_tree().get_first_node_in_group("clusterManager").target
	var tpos = target.global_position + Vector3(0, targetHeight, 0)
	var hitSqrd = hitRadius * hitRadius
	var i = 0
	while i < count:
		var vel = boneVel[i]
		vel.y -= gravity * delta
		var pos = bonePos[i] + vel * delta
		boneVel[i] = vel
		bonePos[i] = pos
		boneLife[i] -= delta
		boneSpin[i] += spinSpeed * delta
		var gone = boneLife[i] <=0 or pos.y <= groundY
		if not gone and pos.distance_squared_to(tpos) <= hitSqrd:
			gone = true
			if target.has_method("_damage"):
				target._damage(boneDmg[i])
			var kbDir = vel
			kbDir.y = 0
			if kbDir.length_squared() < .0001:
				kbDir = Vector3.FORWARD
			target._applyImpulse(pos, (kbDir.normalized() + Vector3.UP * .35).normalized(), boneKb[i])
		if gone:
			_swapOut(i)
			continue
		var fwd = vel
		var len = fwd.length()
		if len > .001:
			fwd /= len
		else:
			fwd = Vector3.UP
		var side = fwd.cross(Vector3.UP)
		if side.length_squared() < .0001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		var bas = Basis(side,fwd,side.cross(fwd).rotated(side, boneSpin[i]))
		mm.set_instance_transform(i, Transform3D(bas,pos))
		i+= 1
	mm.visible_instance_count = count
	
	
	

#testing+_+

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		var cam = get_viewport().get_camera_3d()
		var origin = cam.global_position + Vector3(0, 3,0) - cam.global_transform.basis.z * 12.0
		for i in 7:
			var t = float(i) / 6.0 * 2 - 1
			var dir = (cam.global_position- origin)
			dir.y = 0
			dir = dir.normalized().rotated(Vector3.UP, t * deg_to_rad(24))
			_spawn(origin, dir * 26.0 + Vector3.UP * 6.0, 16.0, 24.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
