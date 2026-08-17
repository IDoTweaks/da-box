extends Node3D
@export var player : CharacterBody3D
@export var shotgunManager : Node3D

var roboCount := 0
var robuddies := []
var roboDmgMult := 1.0
var roboRateMult := 1.0
var roboPerce := 0.0
var roboRangeBonus := 0.0

@onready var robuddy = preload("res://Objects/robuddy.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("upgradeManager")

func _robuddyUpgrade():
	var temp = robuddy.instantiate()
	temp.player = player
	get_tree().current_scene.add_child(temp)
	temp.global_position = player.global_position
	temp.angle = roboCount * TAU / 3
	temp.dmg *= roboDmgMult
	temp.fireInterval *= roboRateMult
	temp.perceDmg = roboPerce
	temp.fireRange += roboRangeBonus
	robuddies.append(temp)
	roboCount += 1
	return "i know you are bad at making friends... since i couldnt get a real human to agree to being your friend you get a robot!"

func _bigBoyUpgrade():
	player._setSize(player.size * 1.25)
	shotgunManager.dmg *= 1.18
	return "stop breathing so much! you fucking inflated"

func _advancedCalcuklatingUpgrade():
	roboPerce += .1
	for robo in robuddies:
		robo.perceDmg =roboPerce
	return "your robuddies can now calculate % and they are ADDICTED"

func _goldPlatedUpgrade():
	roboRateMult *= .65
	for robot in robuddies:
		robot.fireInterval *= .65
	return "your robuddies got a hardware grant and decided to stack them to get some gold plated parts"

func _evilAiUpgrade():
	roboDmgMult *= 1.75
	for robot in robuddies:
		robot.dmg *= 1.75
	return "your robots decided to buy lots of fighting books and burn them! but at least they kill better YAYY"

func _titanUpgrade():
	player._setSize(player.size * 1.6)
	player.maxHealth += 50
	player._heal(50)
	return "collosal titan type shit"

func _birthControlUpgrade():
	player.birthControl = true
	return "lets you control how pregenant you are using the mouse wheel"

func _noop():
	pass

func _astronautUpgrade():
	player.gravityMult *= .5
	return "moon gravity enabled!"

func _punisherUpgrade():
	shotgunManager.dmg *= 1.5
	return "JUDGE! JURY! EXECUTIONER!"

func _rugUpgrade():
	player.kbMult *= 1.5
	return "become a rugdoll! except that idk how to use them so just become a punching bag T_T"

func _triggerFingerUpgrade():
	player._reduceCd(.75)
	return "put your cornHub muscle memory into use"

func _heatResistanceUpgrade():
	player.maxSpeed += player.maxSpeed / 5
	return "makes you clothing more heat resistant allowing you to achive higher speeds"

func _ammoDropUpgrade():
	shotgunManager.bullets += randi_range(1,3)
	shotgunManager.spread += 1.5
	return "get foreign aid but from one guy and his almost empty stock of bullets"

func _windUpUpgrade():
	shotgunManager.speed *= 1.35
	shotgunManager.bulletGravity *= .85
	return "the dev of this game decided to straight up steal cards from rounds so you now have faster bullets"
	

func _barrelDietUpgrade():
	shotgunManager.spread = maxf(shotgunManager.spread * .65, .15)
	return "your barrel started a diet making the bullet spread to go down"

func _thrusterUpgrade():
	shotgunManager.recoil *= 1.5
	shotgunManager.speed *= 1.1
	return "you stole a thruster from nasa and put it on your gun"

func _longBarrelUpgrade():
	shotgunManager.bulletLife += 1.0
	shotgunManager.speed *= 1.2
	return "compensating for something? yes do bullets fly further? also yes"

func _shawarmaRoundsUpgrade():
	shotgunManager.bulletSize *= 1.5
	shotgunManager.speed *= .85
	return "your bullets ate shawarma. THATS IT THEY JUST WANTED SHAWARMA OK?"
	

func _cannonBallUpgrade():
	shotgunManager.bulletSize *= 1.9
	shotgunManager.dmg *= 1.35
	shotgunManager.bullets = maxi(shotgunManager.bullets - 1,1)
	shotgunManager.recoil *= 1.3
	return "your bullets become cannonballs"
	

func _birdshotUpgrade():
	shotgunManager.bulletSize *= .75
	shotgunManager.bullets += 3
	shotgunManager.spread += 2.5
	return "yay you get confetti!"
	

func _momentumUpgrade():
	shotgunManager.velocityDmg += .35
	return "running fast makes you bullets angry"

func _overpressureUpgrade():
	shotgunManager.dmg *= 1.4
	shotgunManager.speed *= .8
	shotgunManager.bulletGravity *= 1.25
	return "uhhh i dont have enything for this one you so ill just tell you what it does get more damage and bullet gravity and less speed "
	

func _railgunUpgrade():
	shotgunManager.dmg += shotgunManager.speed * .2
	shotgunManager.speed *= .75
	shotgunManager.spread = maxf(shotgunManager.spread * .7, .15)
	return "okay fuck it i can write whatever, boom magic more damage less speed and spread because ummm... uhh because an alien said so"

func _tracerUpgrade():
	shotgunManager.speed *= 1.5
	shotgunManager.bulletGravity *= .7
	shotgunManager.dmg *= .9
	return "flat fast and allergic to the concept of gravity"

func _ricochetUpgrade():
	shotgunManager.bounces += 2
	shotgunManager.bulletLife += 2
	return "your bullets learned that walls are just suggestions"

func _rubberUpgrade():
	shotgunManager.bounces += 5
	shotgunManager.dmg *= .8
	return "bouncier, softer, weirdly enthusiastic about corners"

func _superballUpgrade():
	var bullets = _bullets()
	bullets.bounceSpeedLoss = minf(bullets.bounceSpeedLoss + .06, .99)
	shotgunManager.bulletLife += 1.0
	return "your bullets stopped losing energy on impact thermodynamics is crying"

func _vampirismUpgrade():
	player.lifesteal += .04
	return "you started drinking whatever comes out of them dont think about it"

func _bloodPactUpgrade():
	player.lifesteal += .10
	player.maxHealth *= .7
	player.health = minf(player.health, player.maxHealth)
	player._updateGui()
	return "way more lifesteal also way less life to steal into"

func _thickSkinUpgrade():
	player.maxHealth += 40
	player._heal(40)
	return "years of emotional damage finally paying off"

func _metabolismUpgrade():
	player.regen += 1.5
	shotgunManager.dmg *= .9
	return "you heal over time now you also need to poop so you do less damage(it makes sense)"

func _armorUpgrade():
	player.damageTakenMult *= .85
	player.maxSpeed *= .9
	return "bolted plates to yourself ur tankier and slower (obviously)"

func _shrinkUpgrade():
	player._setSize(maxf(player.size * .7, .3))
	shotgunManager.dmg *= .85
	return "you shrunk tiny target tiny damage MASSIVE air time"

func _juggernautUpgrade():
	player._setSize(player.size * 1.4)
	player.maxHealth += 60
	player._heal(60)
	player.damageTakenMult *= .9
	player.maxSpeed *= .85
	return "you are now legally a building buildings do not flinch"

func _greasedUpgrade():
	player.friction *= .6
	player.maxSpeed *= 1.15
	return "you oiled up no traction no regrets"

func _blastTuningUpgrade():
	player.explosionFallOff *= .6
	return "your knockback stopped caring about distance so did everyone elses"

func _hairTriggerUpgrade():
	player._reduceCd(.8)
	shotgunManager.dmg *= .92
	return "your finger developed a nervous condition and its great for dps"

func _swarmUpgrade():
	_robuddyUpgrade()
	_robuddyUpgrade()
	player.maxHealth -= 10
	player.health = minf(player.health, player.maxHealth)
	player._updateGui()
	return "TWO robuddies at once they ate part of your health bar as payment"

func _overclockUpgrade():
	roboRateMult *= .7
	roboDmgMult *= .85
	for robot in robuddies:
		robot.fireInterval *= .7
		robot.dmg *= .85
	return "your robuddies fire way faster and think way less"

func _antennaUpgrade():
	roboRangeBonus += 12.0
	for robot in robuddies:
		robot.fireRange += 12.0
	return "robuddies can now snitch on enemies from much further away"

func _coldSnapUpgrade():
	var cluster = _cluster()
	cluster.enemySpeedMult *= .88
	for e in cluster.data:
		cluster.data[e]["stats"]["moveSpeed"] *= .88
	for t in cluster.virtTypes:
		t["speed"] *= .88
	return "everything out there slowed down now its fair and you cant say you fucking lagged"

func _brittleUpgrade():
	var waves = _waves()
	waves.enemyHealthMult *= .88
	return "new arrivals show up with osteoporosis"

func _crowdControlUpgrade():
	var cluster = _cluster()
	cluster.maxAttackers = maxi(cluster.maxAttackers - 1, 1)
	return "they agreed to form an orderly queue fewer of them get to touch you"

func _suppressiveUpgrade():
	var cluster = _cluster()
	cluster.globalFireInterval *= 1.4
	return "you scared them into shooting way less often bullying works"

func _thinFlockUpgrade():
	var waves = _waves()
	waves.flyingShare *= .6
	return "fewer flying ones spawn gravity finally picked a side"

func _giantSlayerUpgrade():
	var cluster = _cluster()
	cluster.bossDmgMult *= 1.7
	shotgunManager.dmg *= .85
	return "you specialized in big targets and forgot how to fight small ones"

func _bountyUpgrade():
	var cluster = _cluster()
	var waves = _waves()
	cluster.bossDmgMult *= 1.3
	waves.bossEveryWaves = maxi(waves.bossEveryWaves - 1, 2)
	return "more bosses show up and you hit them harder hope you like bosses"

func _greedyUpgrade():
	var cards = _cardScreen()
	cards.picks += 1
	player.maxHealth -= 15
	player.health = minf(player.health, player.maxHealth)
	player._updateGui()
	return "pick an extra card every wave greed costs you a little meat"

func _gamblerUpgrade():
	var cards = _cardScreen()
	var waves = _waves()
	cards.picks += 1
	waves.enemyHealthMult *= 1.15
	return "an extra card every wave and everything out there got a gym membership"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _cluster():
	return get_tree().get_first_node_in_group("clusterManager")

func _waves():
	return get_tree().get_first_node_in_group("waveManager")

func _cardScreen():
	return get_tree().get_first_node_in_group("cardScreen")

func _bullets():
	return get_tree().get_first_node_in_group("playerBullets")
