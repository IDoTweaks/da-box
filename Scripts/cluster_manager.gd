extends Node3D

@export var target : Node3D
@export var tickRate := 0.2
@export var maxAttackers := 2
@export var switchPenalty := 3.0
@export var backBias := 2.0

var enemies : Array = []
var data : Dictionary = {}
var slotDirs : Array[Vector3] = []
var tickTimer := 0.0

const DEAFULTS := {
	"moveSpeed":4.0,
	"acceleration":12.0,
	"turnSpeed":8.0,
	"attackRange":2.0,
	"ringRadius":5.0,
	"seperationRadius":1.5,
	"seperationStrength":4.0,
	"waypointToTolerance":.4,
	"flying":false,
	"hoverHeight":3.0,
	"verticalSpeed":3.0,
	"bobAmount":0.0,
	"bobSpeed":2.0,
	"attackPriority":0.0,
	"avoidStrength":2.0,
	"detourDistance":2.0,
}

func _stat(enemy,key):
	var v = enemy.get(key)
	return DEAFULTS[key] if v == null else v

func _register(enemy):
	if enemy in enemies:
		return
	enemies.append(enemy)
	var stats := {}
	for key in DEAFULTS:
		stats[key] = _stat(enemy,key)
	
	var rays := {}
	if stats["flying"]:
		for key in ["up","dwn", "forward", "backward", "right", "left"]:
			var r = enemy.get(key)
			if r is RayCast3D:
				rays[key] = r
	
	data[enemy] = {
		"stats":stats,
		"rays" : rays,
		"slot":-1,
		"path": PackedVector3Array(),
		"idx":0,
		"state": "circle",
		"phase":  randf() * TAU
	}

func _unRegister(enemy):
	enemies.erase(enemy)
	data.erase(enemy)

func _refreshStats(enemy):
	if enemy in data:
		for key in DEAFULTS:
			data[enemy]["stats"][key] = _stat(enemy,key)

func _getState(enemy) ->String:
	return data[enemy]["state"] if enemy in data else "circle"

func _buildSlotDirs(count:int):
	slotDirs.clear()
	if count <=0:
		return
	var baseAngle = randf() * TAU
	for i in count:
		var angle = baseAngle + (TAU/count) * i
		slotDirs.append(Vector3(cos(angle),0,sin(angle)))

func _slotPoint(enemy,slotIndex) -> Vector3:
	var s = data[enemy]["stats"]
	var point = target.global_position + slotDirs[slotIndex] * s["ringRadius"]
	if s["flying"]:
		point.y = target.global_position.y + s["hoverHeight"]
		return point
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)

func _assignSlots():
	_buildSlotDirs(enemies.size())
	if slotDirs.is_empty():
		return
	var forward = -target.global_transform.basis.z
	var taken := []
	for enemy in enemies:
		var best = -1
		var bestCost = INF
		for i in slotDirs.size():
			if i in taken:
				continue
			var cost = enemy.global_position.distance_to(_slotPoint(enemy,i)) - forward.dot(-slotDirs[i]) * backBias
			if i == data[enemy]["slot"]:
				cost -= switchPenalty
			if cost < bestCost:
				bestCost = cost
				best = i
		if best == -1:
			continue
		taken.append(best)
		data[enemy]["slot"] = best

func _assignRoles():
	var sorted = enemies.duplicate()
	sorted.sort_custom(func(a,b):
		var ca = a.global_position.distance_to(target.global_position) - data[a]["stats"]["attackPriority"]
		var cb = b.global_position.distance_to(target.global_position) - data[b]["stats"]["attackPriority"]
		return ca < cb)
	for i in sorted.size():
		data[sorted[i]]["state"] = "attack" if i < maxAttackers else "circle"
	

func _repath():
	var map = get_world_3d().navigation_map
	for enemy in enemies:
		var d = data[enemy]
		if d["slot"]==-1:
			continue
		var goal = target.global_position if d["state"] == "attack" else _slotPoint(enemy,d["slot"])
		if d["stats"]["flying"]:
			if d["state"] == "attack":
				goal.y = target.global_position.y + d["stats"]["hoverHeight"]
			d["path"] = _flyPath(enemy,goal)
		else:
			d["path"] = NavigationServer3D.map_get_path(map,enemy.global_position,goal,true)
		d["idx"] = 0

func _flyPath(enemy,goal : Vector3) -> PackedVector3Array:
	var d = data[enemy]
	var toGoal:Vector3 = goal - enemy.global_position
	if toGoal.length() < .01 or d["rays"].is_empty():
		return PackedVector3Array([goal])
	var goalDir = toGoal.normalized()
	
	var frontkey = ""
	var frontDot = -INF
	for key in d["rays"]:
		var dot = _rayWorldDir(d["rays"][key]).dot(goalDir)
		if dot > frontDot:
			frontDot = dot
			frontkey = key
	if frontkey != "" and _rayClearance(d["rays"][frontkey]) >= 1:
		return PackedVector3Array([goal])
	
	var best = Vector3.ZERO
	var bestScore =  -INF
	for key in d["rays"]:
		var dir = _rayWorldDir(d["rays"][key])
		var score = _rayClearance(d["rays"][key]) * 2 + dir.dot(goalDir)
		if score > bestScore:
			bestScore = score
			best = dir
	if best == Vector3.ZERO:
		return PackedVector3Array([goal])
	return PackedVector3Array([enemy.global_position + best * d["stats"]["detourDistance"], goal])
	
	

func _seperation(enemy)-> Vector3:
	var s = data[enemy]["stats"]
	var push = Vector3.ZERO
	for other in enemies:
		if other == enemy:
			continue
		var away = enemy.global_position - other.global_position
		if !s["flying"]:
			away.y = 0
		var dist = away.length()
		if dist > .01 and dist < s["seperationRadius"]:
			push += away.normalized() * (1 - dist / s["seperationRadius"])
	return push * s["seperationStrength"]

func _moveEnemy(enemy,delta):
	var d = data[enemy]
	var s = d["stats"]
	var dir = Vector3.ZERO
	var flat = enemy.global_position.distance_to(target.global_position)
	var arrived = d["state"] == "attack" and flat <= s["attackRange"]
	
	if !arrived && d["idx"] < d["path"].size():
		var toWaypoint = d["path"][d["idx"]] - enemy.global_position
		if not s["flying"]:
			toWaypoint.y = 0
		if toWaypoint.length() < s["waypointToTolerance"]:
			d["idx"] +=1
		else:
			dir = toWaypoint.normalized()
	
	var desired = dir * s["moveSpeed"] + _seperation(enemy)
	
	if s["flying"]:
		desired += _rayAvoidance(enemy) * s["avoidStrength"] *s["moveSpeed"]
		if s["bobAmount"] > 0:
			d["phase"] += delta * s["bobSpeed"]
			desired.y += sin(d["phase"]) * s["bobAmount"]
		desired.y = clamp(desired.y, -s["verticalSpeed"],s["verticalSpeed"])
		enemy.velocity = enemy.velocity.move_toward(desired, s["acceleration"] * delta)
	else:
		var flatDesired = Vector3(desired.x,0, desired.z)
		var flatCurrent = Vector3(enemy.velocity.x,0,enemy.velocity.z)
		flatCurrent = flatCurrent.move_toward(flatDesired,s["acceleration"] * delta)
		enemy.velocity.x = flatCurrent.x
		enemy.velocity.z = flatCurrent.z
		if not enemy.is_on_floor():
			enemy.velocity += enemy.get_gravity()*delta
		else:
			enemy.velocity.y = 0
	enemy.move_and_slide()
	
	var look = target.global_position
	if not s["flying"]:
		look.y = enemy.global_position.y
	if enemy.global_position.distance_to(look) > .1:
		var wanted = enemy.global_transform.looking_at(look,Vector3.UP)
		enemy.global_transform.basis = enemy.global_transform.basis.slerp(wanted.basis, clamp(s["turnSpeed"] * delta,0,1))

func _rayClearance(ray: RayCast3D)-> float:
	var maxLeng = ray.target_position.length()
	if maxLeng <= 0:
		return 1
	ray.force_raycast_update()
	if not ray.is_colliding():
		return 1
	var dist = ray.global_position.distance_to(ray.get_collision_point())
	return clamp(dist/ maxLeng, 0, 1)
	

func _rayWorldDir(ray : RayCast3D) ->Vector3:
	return (ray.to_global(ray.target_position) - ray.global_position).normalized()

func _rayAvoidance(enemy) -> Vector3:
	var d = data[enemy]
	var push = Vector3.ZERO
	for key in d["rays"]:
		var ray : RayCast3D = d["rays"][key]
		if !is_instance_valid(ray):
			continue
		var clear = _rayClearance(ray)
		if clear >= 1:
			continue
		push += ray.get_collision_normal() * (1.0 - clear)
		
	return push




func _physics_process(delta: float) -> void:
	if target == null:
		return
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			_unRegister(enemy)
	
	tickTimer -= delta
	if tickTimer <= 0:
		tickTimer = tickRate
		_assignRoles()
		_assignSlots()
		_repath()
	for enemy in enemies:
		_moveEnemy(enemy, delta)
