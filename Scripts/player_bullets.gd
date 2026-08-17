extends MultiMeshInstance3D

@export var maxBullets := 512
@export var hitMask := 5
@export var groundY := -.9
@export var trailScale := 1.0

var bullPos : PackedVector3Array
var bullVel : PackedVector3Array
var bullLife : PackedFloat32Array
var bullDmg : PackedFloat32Array
var bullGrav : PackedFloat32Array
var count := 0
var cluster
var player
var ray : PhysicsRayQueryParameters3D
var mm : MultiMesh


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("playerBullets")
	bullPos.resize(maxBullets)
	bullVel.resize(maxBullets)
	bullLife.resize(maxBullets)
	bullDmg.resize(maxBullets)
	bullGrav.resize(maxBullets)
	ray =PhysicsRayQueryParameters3D.new()
	ray.collision_mask = hitMask
	mm = multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = maxBullets
	mm.visible_instance_count = 0
	

func _spawn(pos: Vector3,vel : Vector3, dmg, grav, life):
	if count >= maxBullets:
		return
	bullPos[count] = pos
	bullVel[count] = vel
	bullDmg[count] = dmg
	bullGrav[count] = grav
	bullLife[count] = life
	count +=1
	

func _swapOut(i):
	count -= 1
	bullPos[i] = bullPos[count]
	bullVel[i] = bullVel[count]
	bullDmg[i] = bullDmg[count]
	bullGrav[i] = bullGrav[count]
	bullLife[i] = bullLife[count]
	

func _physics_process(delta: float) -> void:
	if count == 0:
		if mm.visible_instance_count != 0:
			mm.visible_instance_count = 0
		return
	if cluster == null:
		cluster = get_tree().get_first_node_in_group("clusterManager")
		player = cluster.target
	var space = get_world_3d().direct_space_state
	var didHit := false
	var i := 0
	while i < count:
		bullVel[i].y -= bullGrav[i] * delta
		bullLife[i] -= delta
		var from = bullPos[i]
		var to = from + bullVel[i] * delta
		var seg = to - from
		var dist = seg.length()
		var gone = bullLife[i] <=0 or to.y <= groundY
		if dist > .0001:
			var dir = seg / dist
			ray.from = from
			ray.to = to
			var hit = space.intersect_ray(ray)
			var maxT = dist
			var body
			if hit:
				maxT = from.distance_to(hit["position"])
				body = hit["collider"]
				
			var t = -1
			t = cluster._pelletHit(from, dir, maxT, bullDmg[i])
			if t > 0:
				to = from + dir*t
				gone = true
				didHit = true
			elif  body:
				to = hit["position"]
				gone = true
				if body.has_method("_damage"):
					body._damage(bullDmg[i])
					didHit = true
				
		bullPos[i] = to
		if gone:
			_swapOut(i)
			continue
		var fwd = bullVel[i]
		var len = fwd.length()
		if len > .001:
			fwd /= len
		else:
			fwd = Vector3.FORWARD
		var side = Vector3.UP.cross(fwd)
		if side.length_squared() < .0001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		var bas = Basis(side, fwd.cross(side),fwd)
		mm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(1,1, trailScale)), to))
		i+= 1
		
	mm.visible_instance_count = count
	if didHit and player.has_method("_onBulletHit"):
		player.onBulletHit()
	
	
	

#test without left click cause im too fucking scared to break something
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		var cam = get_viewport().get_camera_3d()
		_spawn(cam.global_position, -cam.global_transform.basis.z * 45,25,25,3)
	
