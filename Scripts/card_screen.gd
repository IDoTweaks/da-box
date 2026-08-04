extends CanvasLayer

var cards = [
	{"title":"big boy","desc":"increases your size by 25%","effect":"_bigBoyUpgrade"},
	{"title":"titan","desc":"increases your size by 60%","effect":"_titanUpgrade"},
	{"title":"placeholder c","desc":"does nothing yet","effect":"_noop"},
	{"title":"placeholder d","desc":"does nothing yet","effect":"_noop"},
	{"title":"placeholder e","desc":"does nothing yet","effect":"_noop"},
	{"title":"placeholder f","desc":"does nothing yet","effect":"_noop"},
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
	for i in cards.size():
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
