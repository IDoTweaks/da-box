extends CanvasLayer


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
]
var shown = [0,0,0]
var pool : Array = []
var waves = null
var upgrades = null

@onready var title = $dim/title
@onready var buttons = [$dim/row/card0,$dim/row/card1,$dim/row/card2]

func _ready() -> void:
	add_to_group("cardScreen")
	for i in buttons.size():
		buttons[i].pressed.connect(_pick.bind(i))

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
		buttons[i].get_node("text/cardTitle").text = c["title"]
		buttons[i].get_node("text/cardDesc").text = c["desc"]

func _open(caller,waveNum):
	waves = caller
	_roll()
	title.text = "wave " + str(waveNum)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _close():
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pick(slot):
	if upgrades == null:
		upgrades = get_tree().get_first_node_in_group("upgradeManager")
	upgrades.call(cards[shown[slot]]["effect"])
	_close()
	waves._onCardPicked()
