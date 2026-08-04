extends Node3D

@export var target : Node3D
@export var tickRate := 0.2
@export var maxAttackers := 2
@export var switchPenalty := 3.0
@export var backBias := 2.0
@export var globalFireInterval := .5
@export var losMask :=1
@export var cellSize := 3.0
@export var slotWindow := 8
@export var maxNeighbours := 10
@export var repathBudget := 60
@export var promoteDistance := 20.0
@export var demoteDistance := 26.0
@export var promoteBudget := 8
@export var maxBodies := 250
@export var virtStride := 2
@export var virtSepPush := 1.2
@export var floorY := -1.0

var globalFireTimer := 0.0
var enemies : Array = []
var data : Dictionary = {}
var slotDirs : Array[Vector3] = []
var tickTimer := 0.0
var grid : Dictionary = {}
var baseAngle := 0.0
var repathCursor := 0
var frameCount := 0

var virtPos : PackedVector3Array
var virtHealth : PackedFloat32Array
var virtMax : PackedFloat32Array
var virtType : PackedInt32Array
var virtTypes : Array = []
var virtGrid : Dictionary = {}
var pools : Array = []
var mmis : Array = []

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
	"fireCooldown":2.0,
	"fireRange":40.0,
	"windUp":.5,
	"needsLineOfSight":true,
}

func _ready() -> void:
	add_to_group("clusterManager")

func _stat(enemy,key):
	var v = enemy.get(key)
	return DEAFULTS[key] if v == null else v

func _register(enemy):
	if data.has(enemy):
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
		"phase":  randf() * TAU,
		"nextFire" : randf() * stats["fireCooldown"],
		"windUp" : -1.0,
		"avoid" : Vector3.ZERO,
		"fireRangeSq" : stats["fireRange"] * stats["fireRange"],
		"poolType" : -1
	}

func _unRegister(enemy):
	var i = enemies.find(enemy)
	if i != -1:
		enemies[i] = enemies[enemies.size() - 1]
		enemies.pop_back()
	data.erase(enemy)

func _despawn(enemy):
	var pt = data[enemy]["poolType"] if data.has(enemy) else -1
	_unRegister(enemy)
	if pt >= 0:
		enemy.get_parent().remove_child(enemy)
		pools[pt].append(enemy)
	else:
		enemy.queue_free()

func _refreshStats(enemy):
	if enemy in data:
		for key in DEAFULTS:
			data[enemy]["stats"][key] = _stat(enemy,key)

func _getState(enemy) ->String:
	return data[enemy]["state"] if enemy in data else "circle"

func _findMesh(node, xform) -> Array:
	for child in node.get_children():
		var cx = xform
		if child is Node3D:
			cx = xform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			return [child.mesh, cx]
		var found = _findMesh(child, cx)
		if not found.is_empty():
			return found
	return []

func _registerType(scene) -> int:
	for i in virtTypes.size():
		if virtTypes[i]["scene"] == scene:
			return i
	var temp = scene.instantiate()
	var found = _findMesh(temp, Transform3D())
	var mesh = BoxMesh.new()
	var meshXform = Transform3D()
	if not found.is_empty():
		mesh = found[0]
		meshXform = found[1]
	var t = {
		"scene": scene,
		"mesh": mesh,
		"meshXform": meshXform,
		"speed": _stat(temp,"moveSpeed"),
		"flying": _stat(temp,"flying"),
		"hover": _stat(temp,"hoverHeight"),
		"hitRadius": temp.get("hitRadius") if temp.get("hitRadius") != null else .9,
		"maxHealth": float(temp.get("health") if temp.get("health") != null else 100)
	}
	temp.free()
	virtTypes.append(t)
	pools.append([])
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 5000
	mm.visible_instance_count = 0
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	mmis.append(mmi)
	return virtTypes.size() - 1

func _spawnVirtual(typeIdx, pos : Vector3, health : float):
	virtPos.append(pos)
	virtHealth.append(health)
	virtMax.append(health)
	virtType.append(typeIdx)

func _totalAlive():
	return enemies.size() + virtPos.size()

func _virtCell(pos) -> Vector2i:
	return Vector2i(floor(pos.x / cellSize), floor(pos.z / cellSize))

func _buildVirtGrid():
	virtGrid.clear()
	for i in virtPos.size():
		var cell = _virtCell(virtPos[i])
		if not virtGrid.has(cell):
			virtGrid[cell] = []
		virtGrid[cell].append(i)

func _compactVirtuals():
	for i in range(virtPos.size() - 1, -1, -1):
		if virtHealth[i] > 0:
			continue
		var last = virtPos.size() - 1
		virtPos[i] = virtPos[last]
		virtHealth[i] = virtHealth[last]
		virtMax[i] = virtMax[last]
		virtType[i] = virtType[last]
		virtPos.resize(last)
		virtHealth.resize(last)
		virtMax.resize(last)
		virtType.resize(last)

func _virtDie(i):
	var vfx = load("res://particles/explosionVfx.tscn").instantiate()
	vfx.size = .5
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = virtPos[i]
	virtHealth[i] = 0

func _pelletHit(from : Vector3, dir : Vector3, maxDist : float, dmg) -> bool:
	if virtPos.is_empty():
		return false
	var bestI = -1
	var bestT = INF
	var seen := {}
	var steps = int(maxDist / cellSize) + 2
	for s in steps:
		var p = from + dir * minf(s * cellSize, maxDist)
		var base = _virtCell(p)
		for x in range(-1,2):
			for z in range(-1,2):
				var cell = base + Vector2i(x,z)
				if not virtGrid.has(cell):
					continue
				for idx in virtGrid[cell]:
					if seen.has(idx):
						continue
					seen[idx] = true
					if idx >= virtHealth.size() or virtHealth[idx] <= 0:
						continue
					var rel = virtPos[idx] - from
					var t = rel.dot(dir)
					if t < 0 or t > maxDist:
						continue
					var r = virtTypes[virtType[idx]]["hitRadius"]
					if (from + dir * t).distance_squared_to(virtPos[idx]) <= r * r and t < bestT:
						bestT = t
						bestI = idx
	if bestI == -1:
		return false
	virtHealth[bestI] -= dmg
	if virtHealth[bestI] <= 0:
		_virtDie(bestI)
	return true

func _moveVirtuals(delta):
	if virtPos.is_empty():
		return
	var tpos = target.global_position
	for i in virtPos.size():
		if (i + frameCount) % virtStride != 0:
			continue
		var t = virtTypes[virtType[i]]
		var pos = virtPos[i]
		var goal = tpos
		if t["flying"]:
			goal.y = tpos.y + t["hover"]
		else:
			goal.y = pos.y
		var dir = goal - pos
		var d = dir.length()
		if d < .5:
			continue
		pos += dir / d * t["speed"] * delta * virtStride
		var cell = _virtCell(pos)
		if virtGrid.has(cell):
			var pushed = 0
			for j in virtGrid[cell]:
				if j == i:
					continue
				pushed += 1
				if pushed > 4:
					break
				var away = pos - virtPos[j]
				away.y = 0
				var ad = away.length()
				if ad > .01 and ad < 1.2:
					pos += away / ad * virtSepPush * delta * virtStride
		if t["flying"]:
			pos.y = clampf(pos.y, floorY + 1.0, tpos.y + t["hover"] + 2.0)
		else:
			pos.y = floorY
		virtPos[i] = pos

func _updateMultimesh():
	var counts := []
	counts.resize(virtTypes.size())
	counts.fill(0)
	for i in virtPos.size():
		var ti = virtType[i]
		var t = virtTypes[ti]
		var toTarget = target.global_position - virtPos[i]
		var yaw = atan2(toTarget.x, toTarget.z)
		var xf = Transform3D(Basis(Vector3.UP, yaw), virtPos[i]) * t["meshXform"]
		mmis[ti].multimesh.set_instance_transform(counts[ti], xf)
		counts[ti] += 1
	for ti in virtTypes.size():
		mmis[ti].multimesh.visible_instance_count = counts[ti]

func _promoteTick():
	if virtPos.is_empty() or enemies.size() >= maxBodies:
		return
	var pd2 = promoteDistance * promoteDistance
	var cands := []
	var tpos = target.global_position
	for i in virtPos.size():
		if virtHealth[i] <= 0:
			continue
		var d2 = virtPos[i].distance_squared_to(tpos)
		if d2 < pd2:
			cands.append([d2, i])
	if cands.is_empty():
		return
	cands.sort_custom(func(a,b): return a[0] < b[0])
	var chosen := []
	for k in mini(promoteBudget, cands.size()):
		if enemies.size() + chosen.size() >= maxBodies:
			break
		chosen.append(cands[k][1])
	chosen.sort()
	chosen.reverse()
	for i in chosen:
		_promote(i)

func _promote(i):
	var typeIdx = virtType[i]
	var body = _takeBody(typeIdx)
	body.global_position = virtPos[i]
	body.maxHealth = virtMax[i]
	body.health = virtHealth[i]
	body._updateHealthBar()
	data[body]["poolType"] = typeIdx
	var last = virtPos.size() - 1
	virtPos[i] = virtPos[last]
	virtHealth[i] = virtHealth[last]
	virtMax[i] = virtMax[last]
	virtType[i] = virtType[last]
	virtPos.resize(last)
	virtHealth.resize(last)
	virtMax.resize(last)
	virtType.resize(last)

func _takeBody(typeIdx):
	var body
	if pools[typeIdx].size() > 0:
		body = pools[typeIdx].pop_back()
		get_tree().current_scene.add_child(body)
		body._reset()
		_register(body)
	else:
		body = virtTypes[typeIdx]["scene"].instantiate()
		body.clusterManager = self
		get_tree().current_scene.add_child(body)
	return body

func _demoteTick():
	var dd2 = demoteDistance * demoteDistance
	var tpos = target.global_position
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var d = data[enemy]
		if d["poolType"] < 0:
			continue
		if enemy.global_position.distance_squared_to(tpos) <= dd2:
			continue
		_spawnVirtual(d["poolType"], enemy.global_position, enemy.health)
		virtMax[virtMax.size() - 1] = enemy.maxHealth
		_despawn(enemy)

func _cellOf(pos) -> Vector2i:
	return Vector2i(floor(pos.x / cellSize), floor(pos.z / cellSize))

func _buildGrid():
	grid.clear()
	for enemy in enemies:
		var cell = _cellOf(enemy.global_position)
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(enemy)

func _buildSlotDirs(count:int):
	slotDirs.clear()
	if count <=0:
		return
	baseAngle = randf() * TAU
	for i in count:
		var angle = baseAngle + (TAU/count) * i
		slotDirs.append(Vector3(cos(angle),0,sin(angle)))

func _ringPoint(enemy,slotIndex) -> Vector3:
	return target.global_position + slotDirs[slotIndex] * data[enemy]["stats"]["ringRadius"]

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
	var taken := {}
	var count = slotDirs.size()
	var step = TAU / count
	for enemy in enemies:
		var offset = enemy.global_position - target.global_position
		var want = int(round((atan2(offset.z, offset.x) - baseAngle) / step))
		var best = -1
		var bestCost = INF
		for w in range(-slotWindow, slotWindow + 1):
			var i = wrapi(want + w, 0, count)
			if taken.has(i):
				continue
			var cost = enemy.global_position.distance_to(_ringPoint(enemy,i)) - forward.dot(-slotDirs[i]) * backBias
			if i == data[enemy]["slot"]:
				cost -= switchPenalty
			if cost < bestCost:
				bestCost = cost
				best = i
		if best == -1:
			best = wrapi(want, 0, count)
		taken[best] = true
		data[enemy]["slot"] = best

func _assignRoles():
	for enemy in enemies:
		data[enemy]["state"] = "circle"
	var picked := []
	for n in maxAttackers:
		var best = null
		var bestCost = INF
		for enemy in enemies:
			if enemy in picked:
				continue
			var cost = enemy.global_position.distance_to(target.global_position) - data[enemy]["stats"]["attackPriority"]
			if cost < bestCost:
				bestCost = cost
				best = enemy
		if best == null:
			break
		picked.append(best)
		data[best]["state"] = "attack"

func _hasLineOfSight(enemy) ->bool:
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(enemy.global_position, target.global_position)
	query.collision_mask = losMask
	var excluds := [enemy.get_rid()]
	if target is CollisionObject3D:
		excluds.append(target.get_rid())
	query.exclude = excluds
	return space.intersect_ray(query).is_empty()

func _fire(enemy):
	var d = data[enemy]
	d["windUp"] = -1.0
	if enemy.has_method("_attack"):
		enemy._attack(target)
	elif enemy.has_method("_shootRocket"):
		enemy._shootRocket(target)

func _updateShooting(delta):
	globalFireTimer -=delta
	var tpos = target.global_position
	for enemy in enemies:
		var d = data[enemy]
		if d["windUp"] > 0:
			d["windUp"] -= delta
			if d["windUp"] <= 0:
				_fire(enemy)
			continue
		d["nextFire"] -=delta
		if d["nextFire"] > 0 or globalFireTimer >0 or d["state"] != "attack" or enemy.global_position.distance_squared_to(tpos) > d["fireRangeSq"]:
			continue
		var s = d["stats"]
		if s["needsLineOfSight"] and !_hasLineOfSight(enemy):
			continue
		globalFireTimer = globalFireInterval
		d["nextFire"] = s["fireCooldown"] * randf_range(.85,1.15)
		if s["windUp"] > 0:
			d["windUp"] = s["windUp"]
			if enemy.has_method("_telegraph"):
				enemy._telegraph(s["windUp"])
		else:
			_fire(enemy)

func _updateAvoidance():
	for enemy in enemies:
		var d = data[enemy]
		if d["rays"].is_empty():
			continue
		d["avoid"] = _rayAvoidance(enemy)

func _repathOne(enemy,map):
	var d = data[enemy]
	if d["slot"]==-1:
		return
	var goal = target.global_position if d["state"] == "attack" else _slotPoint(enemy,d["slot"])
	if d["stats"]["flying"]:
		if d["state"] == "attack":
			goal.y = target.global_position.y + d["stats"]["hoverHeight"]
		d["path"] = _flyPath(enemy,goal)
	else:
		d["path"] = NavigationServer3D.map_get_path(map,enemy.global_position,goal,true)
	d["idx"] = 0

func _repath():
	var count = enemies.size()
	if count == 0:
		return
	var map = get_world_3d().navigation_map
	for enemy in enemies:
		if data[enemy]["state"] == "attack":
			_repathOne(enemy,map)
	var budget = min(repathBudget, count)
	for i in budget:
		var enemy = enemies[(repathCursor + i) % count]
		if data[enemy]["state"] != "attack":
			_repathOne(enemy,map)
	repathCursor = (repathCursor + budget) % count

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
	var base = _cellOf(enemy.global_position)
	var checked = 0
	for x in range(-1,2):
		for z in range(-1,2):
			var cell = base + Vector2i(x,z)
			if not grid.has(cell):
				continue
			for other in grid[cell]:
				if other == enemy:
					continue
				checked += 1
				if checked > maxNeighbours:
					return push * s["seperationStrength"]
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
	var arrived = d["state"] == "attack" and enemy.global_position.distance_squared_to(target.global_position) <= s["attackRange"] * s["attackRange"]

	if !arrived:
		if d["idx"] < d["path"].size():
			var toWaypoint = d["path"][d["idx"]] - enemy.global_position
			if not s["flying"]:
				toWaypoint.y = 0
			if toWaypoint.length() < s["waypointToTolerance"]:
				d["idx"] +=1
			else:
				dir = toWaypoint.normalized()
		else:
			var toTarget = target.global_position - enemy.global_position
			if not s["flying"]:
				toTarget.y = 0
			if toTarget.length() > .01:
				dir = toTarget.normalized()

	var desired = dir * s["moveSpeed"] + _seperation(enemy)

	if s["flying"]:
		desired += d["avoid"] * s["avoidStrength"] *s["moveSpeed"]
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
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			var gone = enemies[i]
			enemies[i] = enemies[enemies.size() - 1]
			enemies.pop_back()
			data.erase(gone)

	frameCount += 1
	_compactVirtuals()
	_buildVirtGrid()
	_moveVirtuals(delta)
	_updateMultimesh()

	tickTimer -= delta
	if tickTimer <= 0:
		tickTimer = tickRate
		_promoteTick()
		_demoteTick()
		_assignRoles()
		_assignSlots()
		_updateAvoidance()
		_repath()
	_updateShooting(delta)
	_buildGrid()
	for enemy in enemies:
		_moveEnemy(enemy, delta)
