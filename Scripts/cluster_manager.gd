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
@export var targetRadiusMult := .5
@export var bodyRadiusPad := 1.15
@export var walkCycle := 9.0
@export var walkBob := .08
@export var walkSway := .1
@export var riseTime := 1.3
@export var riseDepth := 2.4
@export var riseTilt := .9
@export var riseLurch := 14.0
@export var riseWobble := .35
@export var assembleTime := .8
@export var assembleSpin := 9.0
@export var assembleDrop := 2.0
@export var hawkDiveInterval := 4.0
@export var hawkGroupSize := 5
@export var hawkStagger := .12
@export var bodyOnlyBelow := 80
@export var bodyOnlyMargin := 20
@export var bodyOnlyBudget := 32
@export var bossBodyOverflow := 4

var globalFireTimer := 0.0
var enemies : Array = []
var data : Dictionary = {}
var slotDirs : Array[Vector3] = []
var tickTimer := 0.0
var grid : Dictionary = {}
var baseAngle := 0.0
var repathCursor := 0
var frameCount := 0
var kills := 0
var hawkTimer := 0.0
var targetRadius := 0.0
var bodyRadius := 0.0
var virtHitT := 0.0
var virtBar
var virtbarFill
var bodyOnly := false

var virtPos : PackedVector3Array
var virtHealth : PackedFloat32Array
var virtMax : PackedFloat32Array
var virtType : PackedInt32Array
var virtSpawn : PackedFloat32Array
var virtTypes : Array = []
var virtGrid : Dictionary = {}
var pools : Array = []
var mmis : Array = []
var mms : Array = []
var virtCounts : Array = []

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
	"diving":false,
	"diveSpeed":24.0,
	"climbSpeed":12.0,
	"diveRest":1.5,
	"charger":false,
}

@onready var explosionVfx = preload("res://particles/explosionVfx.tscn")
@onready var healthbarScene = preload("res://Objects/healthBar.tscn")

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

	var model = enemy.get_node_or_null("model")
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
		"state": "attack" if stats ["charger"] else "circle",
		"move":2 if stats["charger"] else (1 if stats ["diving"] else 0),
		"chg":null,
		"phase":  randf() * TAU,
		"nextFire" : randf() * stats["fireCooldown"],
		"windUp" : -1.0,
		"avoid" : Vector3.ZERO,
		"fireRangeSq" : stats["fireRange"] * stats["fireRange"],
		"poolType" : -1,
		"angle" : randf() * TAU,
		"diveTimer" : 0.0,
		"divePoint" : Vector3.ZERO,
		"model" : model,
		"modelRest" : model.transform if model != null else Transform3D()
	}
	if stats["charger"]:
		data[enemy]["chg"] = _chargerData(enemy)
	
	

func _num(enemy,key,fallback):
	var v = enemy.get(key)
	return fallback if v == null else float(v)

func _chargerData(enemy):
	var cRange = _num(enemy,"chargeRange", 26.0)
	var cMin = _num(enemy,"chargeMinRange", 9.0)
	var cool = _num(enemy,"chargeCooldown", 4.0) #not so cool but cd is use elsewhere -_-
	var slamCool = _num(enemy, "slamCooldown", 5.0)
	
	return {
		"rangeSq" : cRange * cRange,
		"minSq" : cMin * cMin,
		"hit" : _num(enemy,"chargeHitRange", 3.2),
		"speed" : _num(enemy,"chargeSpeed", 20.0),
		"accel" : _num(enemy,"chargeAccel", 80.0),
		"wind" : _num(enemy,"chargeWindUp", .75),
		"time" : _num(enemy,"chargeTime", 1.4),
		"cool" : cool,
		"recover" : _num(enemy,"chargeRecover", 1.2),
		"slam" : _num(enemy,"slamRange", 4.5),
		"slamWind" : _num(enemy,"slamWindUp", .65),
		"slamRecover" : _num(enemy,"slamRecover", 1.0),
		"slamCool" : slamCool,
		"slamCd" : slamCool * .5,
		"last" : "",
		"timer" : 0.0,
		"cd" : cool * .5,
		"dir" : Vector3.FORWARD,
	}
	


func _unRegister(enemy):
	var i = enemies.find(enemy)
	if i != -1:
		enemies[i] = enemies[enemies.size() - 1]
		enemies.pop_back()
	data.erase(enemy)

func _despawn(enemy):
	if enemy.dead:
		kills +=1
	var pt = data[enemy]["poolType"] if data.has(enemy) else -1
	if data.has(enemy) and data[enemy]["model"] != null:
		data[enemy]["model"].transform = data[enemy]["modelRest"]
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
	var virt = temp.get_node_or_null("virtMesh")
	var found = []
	if virt != null and virt.mesh:
		found = [virt.mesh, virt.transform]
	else:
		found = _findMesh(temp,Transform3D())
	var mesh = BoxMesh.new()
	#var found = _findMesh(temp, Transform3D())
	#var mesh = BoxMesh.new()
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
		"orbit": _stat(temp,"ringRadius") if _stat(temp,"diving") else 0.0,
		"hitRadius": temp.get("hitRadius") if temp.get("hitRadius") != null else .9,
		"hitY": temp.get("hitHeight") if temp.get("hitHeight") != null else 0.0,
		"maxHealth": float(temp.get("health") if temp.get("health") != null else 100),
		"spawnTime": assembleTime if _stat(temp,"flying") else riseTime,
		"barHeight": temp.get("barHeight") if temp.get("barHeight") != null else 2.0,
		"boss": temp.get("isBoss") == true,
	}
	temp.free()
	virtTypes.append(t)
	pools.append([])
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	mm.visible_instance_count = 0
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-160,-10,-160),Vector3(320,80,320))
	add_child(mmi)
	mmis.append(mmi)
	mms.append(mm)
	virtCounts.append(0)
	return virtTypes.size() - 1

func _spawnVirtual(typeIdx, pos : Vector3, health : float, anim = 1.0):
	virtPos.append(pos)
	virtHealth.append(health)
	virtMax.append(health)
	virtType.append(typeIdx)
	virtSpawn.append(anim)

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
		virtSpawn[i] = virtSpawn[last]
		virtPos.resize(last)
		virtHealth.resize(last)
		virtMax.resize(last)
		virtType.resize(last)
		virtSpawn.resize(last)

func _virtDie(i):
	var vfx = explosionVfx.instantiate()
	vfx.size = .5
	get_tree().current_scene.add_child(vfx)
	vfx.global_position = virtPos[i]
	virtHealth[i] = 0
	kills += 1

func _virtualAt(from: Vector3, dir : Vector3,maxDist:float):
	virtHitT = -1
	if virtPos.is_empty():
		return -1
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
					if idx >= virtHealth.size() or virtHealth[idx] <= 0 or virtSpawn[idx] > 0:
						continue
					var vt = virtTypes[virtType[idx]]
					var center = virtPos[idx]
					center.y += vt["hitY"]
					var rel = center - from
					var t = rel.dot(dir)
					if t < 0 or t > maxDist:
						continue
					var r = vt["hitRadius"]
					if (from + dir*t).distance_squared_to(center) <= r * r and t < bestT:
						bestI = idx
						bestT = t
	if bestI == -1:
		return -1
	virtHitT = bestT
	return bestI
	

func _pelletHit(from : Vector3, dir : Vector3, maxDist : float, dmg) -> float:
	var idx = _virtualAt(from,dir,maxDist)
	if idx == -1:
		return -1
	_damageVirtual(idx,dmg)
	return virtHitT

func _showVirtBar(i):
	if virtBar == null:
		virtBar = healthbarScene.instantiate()
		add_child(virtBar)
		virtbarFill = virtBar.get_node("fill")
	virtBar.visible = true
	var vt = virtTypes[virtType[i]]
	virtBar.global_position = virtPos[i] + Vector3(0,vt["barHeight"],0)
	var ratio = maxf(virtHealth[i] / virtMax[i],.001)
	var w = virtbarFill.mesh.size.x
	virtbarFill.scale.x = ratio
	virtbarFill.position.x = -(w * (1-ratio)) / 2
	var cam = get_viewport().get_camera_3d()
	if cam:
		virtBar.look_at(virtBar.global_position + (virtBar.global_position - cam.global_position))
	

func _hideVirtBar():
	if virtBar:
		virtBar.visible = false

func _damageVirtual(i,dmg):
	virtHealth[i] -= dmg
	if virtHealth[i] <= 0:
		_virtDie(i)

func _nearestBody(from: Vector3, maxDist: float):
	var best = null
	var bestDist = maxDist * maxDist
	for enemy in enemies:
		var dist = enemy.global_position.distance_squared_to(from)
		if dist < bestDist:
			bestDist = dist
			best = enemy
	return best
	

func _nearestVirtual(from: Vector3, maxDist: float):
	if virtPos.is_empty():
		return -1
	var base = _virtCell(from)
	var rings =int(maxDist/cellSize) + 1
	var best = -1
	var bestDist = maxDist * maxDist
	for ring in rings:
		for x in range(-ring,ring + 1):
			for z in range(-ring,ring + 1):
				if absi(x) != ring and absi(z) != ring:
					continue
				var cell = base + Vector2i(x,z)
				if not virtGrid.has(cell):
					continue
				for idx in virtGrid[cell]:
					if idx >= virtHealth.size() or virtHealth[idx] <= 0 or virtSpawn[idx] > 0:
						continue
					var dist = virtPos[idx].distance_squared_to(from)
					if dist < bestDist:
						bestDist = dist
						best = idx
		if best != -1:
			return best
	return best


func _moveVirtuals(delta):
	if virtPos.is_empty():
		return
	var tpos = target.global_position
	var stop = .5 + bodyRadius
	for i in virtPos.size():
		if (i + frameCount) % virtStride != 0:
			continue
		var t = virtTypes[virtType[i]]
		if virtSpawn[i] > 0:
			virtSpawn[i] = maxf(virtSpawn[i] - delta * virtStride / t["spawnTime"], 0.0)
			continue
		var pos = virtPos[i]
		var goal = tpos
		if t["flying"]:
			goal.y = tpos.y + t["hover"]
			if t["orbit"] > 0:
				var outX = pos.x - tpos.x
				var outZ = pos.z - tpos.z
				var outLen = sqrt(outX * outX + outZ * outZ)
				if outLen > .01:
					goal.x = tpos.x + outX / outLen * t["orbit"]
					goal.z = tpos.z + outZ / outLen * t["orbit"]
		else:
			goal.y = pos.y
		var dir = goal - pos
		var d = dir.length()
		if d < stop:
			if d < bodyRadius and d > .01:
				virtPos[i] = pos - dir / d * t["speed"] * delta * virtStride
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
	virtCounts.fill(0)
	for i in virtType.size():
		virtCounts[virtType[i]] += 1
	for ti in virtTypes.size():
		var mm = mms[ti]
		if virtCounts[ti] > mm.instance_count:
			mm.instance_count = virtCounts[ti] + 512
		mm.visible_instance_count = virtCounts[ti]
		virtCounts[ti] = 0
	for i in virtPos.size():
		var ti = virtType[i]
		var t = virtTypes[ti]
		var toTarget = target.global_position - virtPos[i]
		var yaw = atan2(toTarget.x, toTarget.z)
		var pos = virtPos[i]
		var s = virtSpawn[i]
		var basis = Basis(Vector3.UP, yaw)
		if s > 0:
			if t["flying"]:
				var k = 1 - s
				basis = Basis(Vector3.UP, yaw + s * s * assembleSpin).scaled(Vector3.ONE * k * k * (3 - 2 * k))
				pos.y += s * s * assembleDrop
			else:
				basis = Basis(Vector3.UP, yaw + sin(s * riseLurch * .6) * riseWobble)
				basis = basis.rotated(basis.x, s * riseTilt + sin(s * riseLurch) * riseWobble * s)
				pos.y -= s * riseDepth
		var xf = Transform3D(basis, pos) * t["meshXform"]
		mms[ti].set_instance_transform(virtCounts[ti], xf)
		virtCounts[ti] += 1

func _updateBodyOnly():
	var total = _totalAlive()
	if bodyOnly:
		bodyOnly = total <= bodyOnlyBelow + bodyOnlyMargin
	else:
		bodyOnly = total <= bodyOnlyBelow

func _promoteAll():
	var budget = bodyOnlyBudget
	for i in range(virtPos.size() - 1,-1,-1):
		if budget <= 0 or enemies.size() >= maxBodies:
			return
		if virtHealth[i] <= 0 or virtSpawn[i] > 0:
			continue
		_promote(i)
		budget -= 1
	


func _promoteTick():
	if virtPos.is_empty():
		return
	if bodyOnly:
		_promoteAll()
	var pd2 = promoteDistance * promoteDistance
	var cands := []
	var chosen := []
	var full = enemies.size() >= maxBodies
	var tpos = target.global_position
	for i in virtPos.size():
		if virtHealth[i] <= 0 or virtSpawn[i] > 0:
			continue
		if virtTypes[virtType[i]]["boss"]:
			if enemies.size() + chosen.size() < maxBodies + bossBodyOverflow:
				chosen.append(i)
			continue
		if full:
			continue
		
		var d2 = virtPos[i].distance_squared_to(tpos)
		if d2 < pd2:
			cands.append([d2, i])
	if !cands.is_empty():
		cands.sort_custom(func(a,b): return a[0] < b[0])
		for k in mini(promoteBudget, cands.size()):
			if enemies.size() + chosen.size() >= maxBodies:
				break
			chosen.append(cands[k][1])
	
	if chosen.is_empty():
		return
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
	virtSpawn[i] = virtSpawn[last]
	virtPos.resize(last)
	virtHealth.resize(last)
	virtMax.resize(last)
	virtType.resize(last)
	virtSpawn.resize(last)

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
	if bodyOnly:
		return
	var dd2 = demoteDistance * demoteDistance
	var tpos = target.global_position
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		var d = data[enemy]
		if d["poolType"] < 0 or virtTypes[d["poolType"]]["boss"] or enemy.global_position.distance_squared_to(tpos) <= dd2:
			continue
		_spawnVirtual(d["poolType"], enemy.global_position, enemy.health, 0.0)
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
	return target.global_position + slotDirs[slotIndex] * (data[enemy]["stats"]["ringRadius"] + targetRadius)

func _slotPoint(enemy,slotIndex) -> Vector3:
	var s = data[enemy]["stats"]
	var point = target.global_position + slotDirs[slotIndex] * (s["ringRadius"] + targetRadius)
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
		var d = data[enemy]
		if d["move"] != 0:
			continue
		var offset = enemy.global_position - target.global_position
		var want = int(round((atan2(offset.z, offset.x) - baseAngle) / step))
		var best = -1
		var bestCost = INF
		for w in range(-slotWindow, slotWindow + 1):
			var i = wrapi(want + w, 0, count)
			if taken.has(i):
				continue
			var cost = enemy.global_position.distance_to(_ringPoint(enemy,i)) - forward.dot(-slotDirs[i]) * backBias
			if i == d["slot"]:
				cost -= switchPenalty
			if cost < bestCost:
				bestCost = cost
				best = i
		if best == -1:
			best = wrapi(want, 0, count)
		taken[best] = true
		d["slot"] = best

func _assignRoles():
	for enemy in enemies:
		var d = data[enemy]
		if d["move"] != 0:
			continue
		d["state"] = "circle"
	var picked := {}
	for n in maxAttackers:
		var best = null
		var bestCost = INF
		for enemy in enemies:
			var d = data[enemy]
			if d["move"] != 0 or picked.has(enemy):
				continue
			var cost = enemy.global_position.distance_to(target.global_position) - data[enemy]["stats"]["attackPriority"]
			if cost < bestCost:
				bestCost = cost
				best = enemy
		if best == null:
			break
		picked[best] = true
		data[best]["state"] = "attack"

func _hawkRoles():
	hawkTimer -= tickRate
	if hawkTimer > 0:
		return
	var flock := []
	for enemy in enemies:
		var d = data[enemy]
		if d["move"] != 1 or d["state"] != "circle" or d["diveTimer"] > 0:
			continue
		flock.append(enemy)
	if flock.is_empty():
		return
	hawkTimer = hawkDiveInterval
	var point = target.global_position
	var leadAngle = data[flock[randi() % flock.size()]]["angle"]
	for n in hawkGroupSize:
		var best = null
		var bestDiff = INF
		for enemy in flock:
			var d = data[enemy]
			if d["state"] != "circle":
				continue
			var diff = absf(angle_difference(d["angle"],leadAngle))
			if diff < bestDiff:
				bestDiff = diff
				best = enemy
		if best == null:
			return
		data[best]["state"] = "dive"
		data[best]["diveTimer"] = n * hawkStagger
		data[best]["divePoint"] = point

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
		if d["nextFire"] > 0 or globalFireTimer >0 or d["state"] != "attack":
			continue
		var s = d["stats"]
		var off = tpos - enemy.global_position
		if not s["flying"]:
			off.y = 0
		var reach = s["fireRange"] + targetRadius
		if off.length_squared() > reach * reach:
			continue
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
	if d["move"] == 2:
		d["path"] = NavigationServer3D.map_get_path(map,enemy.global_position, target.global_position, true)
		d["idx"] = 0
		return
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

func _hawkOrbit(d,s,delta) -> Vector3:
	var radius = s["ringRadius"] + targetRadius
	d["angle"] += delta * s["moveSpeed"] / radius
	var point = target.global_position + Vector3(cos(d["angle"]),0,sin(d["angle"])) * radius
	point.y = target.global_position.y + s["hoverHeight"]
	return point

func _moveHawk(enemy,d,s,delta):
	var tpos = target.global_position
	var goal = _hawkOrbit(d,s,delta)
	var speed = s["moveSpeed"]
	if d["diveTimer"] > 0:
		d["diveTimer"] -= delta
	if d["state"] == "dive" and d["diveTimer"] <= 0:
		goal = d["divePoint"]
		speed = s["diveSpeed"]
		var reach = s["attackRange"] + targetRadius
		if enemy.global_position.distance_squared_to(tpos) <= reach * reach:
			_fire(enemy)
			d["state"] = "climb"
		elif enemy.global_position.y <= goal.y + .2:
			d["state"] = "climb"
	elif d["state"] == "climb":
		speed = s["climbSpeed"]
		if enemy.global_position.y >= tpos.y + s["hoverHeight"] - 1.5:
			d["state"] = "circle"
			d["diveTimer"] = s["diveRest"]

	var dir = goal - enemy.global_position
	var dist = dir.length()
	if dist > .01:
		dir /= dist
	else:
		dir = Vector3.ZERO
	var desired = dir * speed + _seperation(enemy) + d["avoid"] * s["avoidStrength"] * speed
	enemy.velocity = enemy.velocity.move_toward(desired, s["acceleration"] * delta)
	enemy.move_and_slide()
	if Vector2(enemy.velocity.x,enemy.velocity.z).length_squared() > 1.0:
		var wanted = enemy.global_transform.looking_at(enemy.global_position + enemy.velocity,Vector3.UP,true)
		enemy.global_transform.basis = enemy.global_transform.basis.slerp(wanted.basis, clamp(s["turnSpeed"] * delta,0,1))

func _chargerStep(enemy,d):
	var pos = enemy.global_position
	if d["idx"] < d["path"].size():
		var waypoint = d["path"][d["idx"]]
		var offsetWaypointX = waypoint.x - pos.x
		var offsetWaypointZ = waypoint.z - pos.z
		var dist2waypointSqrd = offsetWaypointX * offsetWaypointX + offsetWaypointZ * offsetWaypointZ
		var tol = d["stats"]["waypointToTolerance"]
		if dist2waypointSqrd < tol * tol:
			d["idx"] += 1
		else:
			var dist2waypoint = sqrt(dist2waypointSqrd)
			return Vector3(offsetWaypointX / dist2waypoint,0, offsetWaypointZ / dist2waypoint)
		
	var offsetTargX = target.global_position.x - pos.x
	var offsetTargZ = target.global_position.z - pos.z
	var disttargSqrd = offsetTargX * offsetTargX + offsetTargZ * offsetTargZ
	if disttargSqrd < .0001:
		return Vector3.ZERO
	var dist2targ = sqrt(disttargSqrd)
	return Vector3(offsetTargX /dist2targ, 0, offsetTargZ / dist2targ)
	

func _moveCharger(enemy,d,s,delta):
	var c = d["chg"]
	var pos = enemy.global_position
	var tpos = target.global_position
	var dirX = tpos.x - pos.x
	var dirZ = tpos.z - pos.z
	var distSqrd = dirX * dirX + dirZ * dirZ
	var state = d["state"]
	var dir := Vector3.ZERO
	var speed = s["moveSpeed"]
	var accel = s["acceleration"]
	var pushed = true
	c["cd"] -= delta
	c["slamCd"] -= delta
	
	if state == "attack":
		var slamReach = c["slam"] + targetRadius
		if c["slamCd"] <= 0 and distSqrd <= slamReach * slamReach:
			d["state"] = "slamWind"
			c["timer"] = c["slamWind"]
			if enemy.has_method("_telegraphSlam"):
				enemy._telegraphSlam(c["slamWind"])
		elif c["cd"] <= 0 and distSqrd <= c["rangeSq"] and distSqrd >= c["minSq"]:
			d["state"] = "chargeWind"
			c["timer"] = c["wind"]
			if enemy.has_method("_telegraphCharge"):
				enemy._telegraphCharge(c["wind"])
		else:
			dir = _chargerStep(enemy,d)
	elif  state == "chargeWind":
		c["timer"] -= delta
		if c["timer"] <= 0:
			if distSqrd > .0001:
				var l = sqrt(distSqrd)
				c["dir"] = Vector3(dirX / l, 0, dirZ / l)
			else:
				c["dir"] = -enemy.global_transform.basis.z
			d["state"] = "charge"
			c["timer"] = c["time"]
			
	elif  state == "slamWind":
		c["timer"] -= delta
		if c["timer"] <= 0:
			if enemy.has_method("_slam"):
				enemy._slam(target)
			d["state"] = "recover"
			c["timer"] = c["slamRecover"]
			c["slamCd"] = c["slamCool"]
	
	elif state == "charge":
		dir = c["dir"]
		speed = c["speed"]
		accel = c["accel"]
		pushed = false
		c["timer"] -= delta
		var hitReach = c["hit"] + targetRadius
		if distSqrd <= hitReach * hitReach:
			if enemy.has_method("_chargeHit"):
				enemy._chargeHit(target)
			d["state"] = "recover"
			c["timer"] = c["recover"]
			c["cd"] = c["cool"]
		elif c["timer"] <= 0:
			d["state"] = "recover"
			c["timer"] = c["recover"]
			c["cd"] = c["cool"]
			
	else:
		c["timer"] -= delta
		if c["timer"] <= 0:
			d["state"] = "attack"
	
	var want = dir * speed
	if pushed:
		want += _seperation(enemy)
	var flat = Vector3(enemy.velocity.x,0,enemy.velocity.z).move_toward(Vector3(want.x,0,want.z),accel * delta)
	enemy.velocity.x = flat.x
	enemy.velocity.z = flat.z
	if not enemy.is_on_floor():
		enemy.velocity += enemy.get_gravity() * delta
	else:
		enemy.velocity.y = 0
	enemy.move_and_slide()
	
	if d["state"] == "charge" and enemy.is_on_wall():
		d["state"] = "recover"
		c["timer"] = c["recover"]
		c["cd"] = c["cool"]
	
	var  model = d["model"]
	if model:
		d["phase"] += delta * walkCycle * Vector2(enemy.velocity.x,enemy.velocity.z).length() / s["moveSpeed"]
		var ph = sin(d["phase"])
		var rest = d["modelRest"]
		model.transform = Transform3D(rest.basis.rotated(Vector3.BACK, ph * walkSway), rest.origin + Vector3(0, absf(ph) * walkBob,0))
	
	var lookDir = c["dir"] if d["state"] == "charge" else Vector3(dirX,0,dirZ)
	if lookDir.length_squared() > .0001:
		var wanted = enemy.global_transform.looking_at(enemy.global_position + lookDir,Vector3.UP,true)
		enemy.global_transform.basis = enemy.global_transform.basis.slerp(wanted.basis, clamp(s["turnSpeed"] * delta, 0,1))
	if d["state"] != c["last"]:
		c["last"] = d["state"]
		if enemy.has_method("_onState"):
			enemy._onState(d["state"])
	
	

func _moveEnemy(enemy,delta):
	var d = data[enemy]
	var s = d["stats"]
	var m = d["move"]
	if m == 1:
		_moveHawk(enemy,d,s,delta)
		return
	if m == 2:
		_moveCharger(enemy,d,s,delta)
		return
	var dir = Vector3.ZERO
	var toT = target.global_position - enemy.global_position
	if not s["flying"]:
		toT.y = 0
	var flatSq = toT.length_squared()
	var reach = s["attackRange"] + targetRadius
	var arrived = d["state"] == "attack" and flatSq <= reach * reach
	var inside = not s["flying"] and flatSq < bodyRadius * bodyRadius

	if inside:
		if flatSq > .0001:
			dir = -toT / sqrt(flatSq)
	elif !arrived:
		if d["idx"] < d["path"].size():
			var toWaypoint = d["path"][d["idx"]] - enemy.global_position
			if not s["flying"]:
				toWaypoint.y = 0
			if toWaypoint.length() < s["waypointToTolerance"]:
				d["idx"] +=1
			else:
				dir = toWaypoint.normalized()
		else:
			if flatSq > .0001:
				dir = toT / sqrt(flatSq)

	var desired = dir * s["moveSpeed"] + (Vector3.ZERO if inside else _seperation(enemy))

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

	var model = d["model"]
	if model != null and not s["flying"]:
		d["phase"] += delta * walkCycle * Vector2(enemy.velocity.x,enemy.velocity.z).length() / s["moveSpeed"]
		var ph = sin(d["phase"])
		var rest = d["modelRest"]
		model.transform = Transform3D(rest.basis.rotated(Vector3.BACK,ph * walkSway),rest.origin + Vector3(0,absf(ph) * walkBob,0))

	var look = target.global_position
	if not s["flying"]:
		look.y = enemy.global_position.y
	if enemy.global_position.distance_to(look) > .1:
		var wanted = enemy.global_transform.looking_at(look,Vector3.UP,true)
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
	var ts = target.get("size")
	var tsize = ts if ts != null else 1.0
	targetRadius = max(tsize - 1.0,0.0) * targetRadiusMult
	bodyRadius = tsize * targetRadiusMult * bodyRadiusPad
	_compactVirtuals()
	_buildVirtGrid()
	_moveVirtuals(delta)
	_updateMultimesh()

	tickTimer -= delta
	if tickTimer <= 0:
		tickTimer = tickRate
		_updateBodyOnly()
		_promoteTick()
		_demoteTick()
		_buildVirtGrid()
		_assignRoles()
		_hawkRoles()
		_assignSlots()
		_updateAvoidance()
		_repath()
	_updateShooting(delta)
	_buildGrid()
	for enemy in enemies:
		_moveEnemy(enemy, delta)
