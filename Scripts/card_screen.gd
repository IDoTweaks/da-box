extends CanvasLayer

@export var delTime := .35
@export var dealTiming := .1
@export var flipTime := .15
@export var unClickableTime := .25

#{"title":"","desc":"","effect":""},
var cards = [
	{"title":"advanced calculating","desc":"your robuddies can now calculate % and they are ADDICTED","effect":"_advancedCalcuklatingUpgrade", "robo":true},
	{"title":"gold plated","desc":"your robuddies got a hardware grant and decided to stack them to get some gold plated parts","effect":"_goldPlatedUpgrade", "robo":true},
	{"title":"evil ai","desc":"your robots decided to buy lots of fighting books and burn them! but at least they kill better YAYY","effect":"_evilAiUpgrade", "robo":true},
	{"title":"big boy","desc":"stop breathing so much! you fucking inflated","effect":"_bigBoyUpgrade"},
	{"title":"titan","desc":"collosal titan type shit","effect":"_titanUpgrade"},
	{"title":"birth control","desc":"lets you control how pregenant you are using the mouse wheel","effect":"_birthControlUpgrade"},
	{"title":"astronaut","desc":"moon gravity enabled!","effect":"_astronautUpgrade"},
	{"title":"punisher","desc":"JUDGE! JURY! EXECUTIONER!","effect":"_punisherUpgrade"},
	{"title":"rugdoll","desc":"become a rugdoll! except that idk how to use them so just become a punching bag T_T","effect":"_rugUpgrade"},
	{"title":"trigger finger","desc":"put your cornHub muscle memory into use","effect":"_triggerFingerUpgrade"},
	{"title":"robuddy","desc":"i know you are bad at making friends... since i couldnt get a real human to agree to being your friend you get a robot!","effect":"_robuddyUpgrade"},
	{"title":"ammo drop","desc":"get foreign aid but from one guy and his almost empty stock of bullets","effect":"_ammoDropUpgrade"},
	{"title":"heat resistance","desc":"makes you clothing more heat resistant allowing you to achive higher speeds","effect":"_heatResistanceUpgrade"},
	{"title":"wind up","desc":"the dev of this game decided to straight up steal cards from rounds so you now have faster bullets","effect":"_windUpUpgrade"},
	{"title":"barrel diet","desc":"your barrel started a diet making the bullet spread to go down","effect":"_barrelDietUpgrade"},
	{"title":"thruster gun","desc":"you stole a thruster from nasa and put it on your gun","effect":"_thrusterUpgrade"},
	{"title":"long barrel","desc":"compensating for something? yes do bullets fly further? also yes","effect":"_longBarrelUpgrade"},
]
var shown = [0,0,0]
var pool : Array = []
var waves = null
var upgrades = null
var faceUp = [false,false,false]
var tweens = [null,null,null]
var timer : Timer
var canPick = false
var picks := 1
var picksLeft := 0

@onready var title = $dim/title
@onready var buttons = [$dim/row/card0,$dim/row/card1,$dim/row/card2]

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = unClickableTime
	timer.autostart = false
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(onTimerEnd)
	add_child(timer)
	add_to_group("cardScreen")
	for i in buttons.size():
		buttons[i].pressed.connect(_pick.bind(i))
		buttons[i].mouse_entered.connect(_onCardHover.bind(i,true))
		buttons[i].mouse_exited.connect(_onCardHover.bind(i,false))

func onTimerEnd():
	canPick = true

func _roll():
	pool.clear()
	if upgrades == null:
		upgrades = get_tree().get_first_node_in_group("upgradeManager")
	for i in cards.size():
		if cards[i].has("robo") and upgrades.roboCount == 0:
			continue
		pool.append(i)
	pool.shuffle()
	for i in buttons.size():
		if i >= pool.size():
			buttons[i].visible = false
			continue
		shown[i] = pool[i]
		var c = cards[pool[i]]
		buttons[i].visible = true
		_setFace(i, true)
		buttons[i].get_node("text/cardTitle").text = c["title"]
		buttons[i].get_node("text/cardDesc").text = c["desc"]

func _cardTween(i):
	if tweens[i]:
		tweens[i].kill()
	tweens[i] = create_tween()
	return tweens[i]
	

func _onCardHover(i, isHovered):
	var tween = _cardTween(i)
	var target_scale = Vector2(1.1, 1.1) if isHovered else Vector2(1, 1)
	
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(buttons[i], "scale", target_scale, flipTime)
	
	

func _setFace(i,up):
	buttons[i].get_node("text").visible = up
	buttons[i].get_node("back").visible = !up

func _open(caller,waveNum):
	timer.start()
	waves = caller
	picksLeft = picks
	_roll()
	title.text = "wave " + str(waveNum)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _close():
	canPick = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pick(slot):
	if !canPick:
		return
	if upgrades == null:
		upgrades = get_tree().get_first_node_in_group("upgradeManager")
	upgrades.call(cards[shown[slot]]["effect"])
	picksLeft -= 1
	if picksLeft > 0:
		canPick = false
		timer.start()
		_roll()
		return
	_close()
	waves._onCardPicked()


func _on_golden_ticket_button_pressed() -> void:
	OS.shell_open("https://github.com/IDoTweaks/da-box/blob/main/shhh%20dont%20open%20it%20you%20will%20open%20it%20from%20the%20game!")
