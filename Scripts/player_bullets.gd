extends MultiMeshInstance3D

@export var maxBullets := 512
@export var hitMask := 5
@export var groundY := -5.0
@export var trailScale := 1.0
@export var bounceSpeedLoss := .85
@export var sizePad := .35

var bullPos : PackedVector3Array
var bullVel : PackedVector3Array
var bullLife : PackedFloat32Array
var bullDmg : PackedFloat32Array
var bullGrav : PackedFloat32Array
var bullBounce : PackedInt32Array
var bullSize : PackedFloat32Array
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
	bullBounce.resize(maxBullets)
	bullSize.resize(maxBullets)
	ray =PhysicsRayQueryParameters3D.new()
	ray.collision_mask = hitMask
	mm = multimesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = maxBullets
	mm.visible_instance_count = 0
	

func _spawn(pos: Vector3,vel : Vector3, dmg, grav, life, bounces = 0, size := 1.0):
	if count >= maxBullets:
		return
	bullPos[count] = pos
	bullVel[count] = vel
	bullDmg[count] = dmg
	bullGrav[count] = grav
	bullLife[count] = life
	bullBounce[count] = bounces
	bullSize[count] = size
	count +=1
	

func _swapOut(i):
	count -= 1
	bullPos[i] = bullPos[count]
	bullVel[i] = bullVel[count]
	bullDmg[i] = bullDmg[count]
	bullGrav[i] = bullGrav[count]
	bullLife[i] = bullLife[count]
	bullBounce[i] = bullBounce[count]
	bullSize[i] = bullSize[count]

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
	var hitDmg := 0.0
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
			var wall = space.intersect_ray(ray)
			var maxT = dist
			if wall:
				maxT = from.distance_to(wall["position"])
			var pad = (bullSize[i] - 1) * sizePad
			var idx = cluster._virtualAt(from,dir,maxT,pad)
			var vT = cluster.virtHitT if idx != -1 else INF
			var body = cluster._bodyAT(from, dir, maxT, pad)
			var bT = cluster.bodyHitT if body != null else INF
			if idx != -1 and vT <= bT:
				cluster._damageVirtual(idx, bullDmg[i])
				to = from + dir*vT
				gone = true
				didHit = true
				hitDmg += bullDmg[i]
			elif  body:
				cluster._damageBody(body, bullDmg[i])
				to = from + dir*bT
				didHit = true
				hitDmg += bullDmg[i]
				gone = true
			elif wall:
				if bullBounce[i] > 0:
					bullBounce[i] -= 1
					var normal = wall["normal"]
					bullVel[i] = bullVel[i].bounce(normal) * bounceSpeedLoss
					to = wall["position"] + normal * .05
					gone = bullLife[i] <= 0
					
				else:
					to = wall["position"]
					gone = true
				
				
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
		var size = bullSize[i]
		mm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(size,size, size)), to))
		i+= 1
		
	mm.visible_instance_count = count
	if didHit:
		player._onBulletHit(hitDmg)
	
	
	

#test without left click cause im too fucking scared to break something
#func _input(event: InputEvent) -> void:
#	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
#		var cam = get_viewport().get_camera_3d()
#		_spawn(cam.global_position, -cam.global_transform.basis.z * 45,25,25,3)
#	
