extends Node3D

var waveNumber = 0
var killBase = 0
var waveQuota = 0
var spawnTimer = 0.0
var toSpawn = 0
var bossesToSpawn = 0
var running = false
var choosing = false
var cardScreen = null
var tiers = []
var groundTiers = []
var flyTiers = []
var groundLevels = []
var groundWeights = []
var groundTotal = 0.0
var flyLevels = []
var flyWeights = []
var flyTotal = 0.0

@export var target : Node3D
@export var clusterManager : Node3D

@export var level1 : Array[PackedScene] = []
@export var level2 : Array[PackedScene] = []
@export var level3 : Array[PackedScene] = []
@export var level4 : Array[PackedScene] = []
@export var level5 : Array[PackedScene] = []
@export var level6 : Array[PackedScene] = []

@export var testing := false
@export var autoStart := true
@export var waveTime := 12.0
@export var baseCount := 4
@export var countGrowth := 1.145
@export var spawnInterval := .25
@export var spawnRadius := 24.0
@export var spawnSpread := 8.0
@export var maxAlive := 3000
@export var maxWaveCount := 8000
@export var maxQueued := 12000
@export var healthGrowth := .12
@export var flyHeight := 4.0
@export var levelEveryWaves := 3
@export var topLevel := 5
@export var levelBias := .8
@export var flyingShare := .1
@export var bossEveryWaves := 5
@export var bossLevel := 6
@export var bossWavesPerExtra := 6

func _ready() -> void:
	add_to_group("waveManager")
	tiers = [level1, level2, level3, level4, level5, level6]
	_splitTiers()
	_rebuildLevels()
	if autoStart and not testing:
		_start()

func _splitTiers():
	for list in tiers:
		var ground = []
		var flyers = []
		for scene in list:
			var idx = clusterManager._registerType(scene)
			if clusterManager.virtTypes[idx]["flying"]:
				flyers.append(scene)
			else:
				ground.append(scene)
		groundTiers.append(ground)
		flyTiers.append(flyers)

func _start():
	running = true
	waveNumber = 0
	toSpawn = 0
	bossesToSpawn = 0
	spawnTimer = 1.0
	_nextWave()

func _stop():
	running = false

func _endWave():
	if cardScreen == null:
		cardScreen = get_tree().get_first_node_in_group("cardScreen")
	if cardScreen == null:
		_nextWave()
		return
	choosing = true
	cardScreen._open(self,waveNumber + 1)

func _onCardPicked():
	choosing = false
	_nextWave()

func _nextWave():
	waveNumber += 1
	var count = _waveCount(waveNumber)
	toSpawn = int(min(toSpawn + _waveCount(waveNumber), maxQueued))
	waveQuota = count
	killBase = clusterManager.kills
	_rebuildLevels()
	if _isBossWave():
		var bosses = _bossCount()
		bossesToSpawn += _bossCount()
		waveQuota += bosses
	

func _waveKills():
	return clusterManager.kills - killBase

func _waveCount(n):
	return int(min(baseCount * pow(countGrowth, n - 1), maxWaveCount))

func _healthMult():
	return 1 + healthGrowth * (waveNumber - 1)

func _maxLevel():
	return clamp(1 + int((waveNumber - 1) / levelEveryWaves), 1, topLevel)

func _isBossWave():
	return waveNumber % bossEveryWaves == 0

func _bossCount():
	return 1 + int(waveNumber / (bossEveryWaves * bossWavesPerExtra))

func _hasTier(lvl):
	if lvl > tiers.size():
		return false
	return not tiers[lvl - 1].is_empty()

func _hasClass(lvl, flying):
	if lvl > tiers.size():
		return false
	var list = flyTiers[lvl - 1] if flying else groundTiers[lvl - 1]
	return not list.is_empty()

func _fillLevels(levels, weights, flying):
	levels.clear()
	weights.clear()
	for lvl in range(1, _maxLevel() + 1):
		if _hasClass(lvl, flying):
			levels.append(lvl)
	if levels.is_empty():
		return 0.0
	var top = levels[levels.size() - 1]
	var total = 0.0
	for lvl in levels:
		var w = pow(levelBias, top - lvl)
		weights.append(w)
		total += w
	return total

func _rebuildLevels():
	groundTotal = _fillLevels(groundLevels, groundWeights, false)
	flyTotal = _fillLevels(flyLevels, flyWeights, true)

func _pickLevel(flying):
	var levels = flyLevels if flying else groundLevels
	if levels.is_empty():
		return 0
	var weights = flyWeights if flying else groundWeights
	var roll = randf() * (flyTotal if flying else groundTotal)
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0:
			return levels[i]
	return levels[levels.size() - 1]

func _pickFrom(lvl, flying):
	var list = flyTiers[lvl - 1] if flying else groundTiers[lvl - 1]
	if list.is_empty():
		list = groundTiers[lvl - 1] if flying else flyTiers[lvl - 1]
	return list[randi() % list.size()]

func _spawnPoint(flying):
	var angle = randf() * TAU
	var dist = spawnRadius + randf() * spawnSpread
	var point = target.global_position + Vector3(cos(angle),0,sin(angle)) * dist
	if flying:
		point.y = target.global_position.y + flyHeight
		return point
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)

func _spawnOne(scene):
	var idx = clusterManager._registerType(scene)
	var t = clusterManager.virtTypes[idx]
	clusterManager._spawnVirtual(idx, _spawnPoint(t["flying"]), t["maxHealth"] * _healthMult())

func _aliveCount():
	return clusterManager._totalAlive()

func _batchSize():
	return max(1, int(ceil((toSpawn + bossesToSpawn) * spawnInterval / waveTime)))

func _spawnBatch():
	var budget = _batchSize()
	for i in budget:
		if _aliveCount() >= maxAlive:
			return
		var flying = randf() < flyingShare
		if bossesToSpawn > 0:
			_spawnOne(_pickFrom(bossLevel, flying))
			bossesToSpawn -= 1
			continue
		if toSpawn <= 0:
			return
		var lvl = _pickLevel(flying)
		if lvl == 0:
			flying = not flying
			lvl = _pickLevel(flying)
		if lvl == 0:
			return
		_spawnOne(_pickFrom(lvl, flying))
		toSpawn -= 1

func _physics_process(delta: float) -> void:
	if testing or not running or choosing or target == null or clusterManager == null:
		return
	if not _hasTier(bossLevel):
		bossesToSpawn = 0
	if _waveKills() >= waveQuota:
		_endWave()
		return
	if toSpawn <= 0 and bossesToSpawn <= 0:
		return
	spawnTimer -= delta
	if spawnTimer > 0:
		return
	spawnTimer = spawnInterval
	_spawnBatch()
