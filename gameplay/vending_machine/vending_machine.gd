extends Node3D
## The card vending machine behind the bench. Pull the lever to buy a random
## card you don't own yet; it pops out of the slot and lands on the ground
## for the player to pick up. Every pull costs more than the last. Cards are
## a mid-game buy: the machine stays shut until wave `opens_at_wave` starts.

const MESSAGE_TIME_MSEC := 2500

@export var game: GameState
@export var station: CardStation
## The machine stays locked before this wave.
@export var opens_at_wave: int = 3
@export var price: int = 250
## How much the price goes up after each card.
@export var price_step: int = 75

@onready var _screen: Label3D = $Screen/Text
@onready var _output: Node3D = $Output
@onready var _display: Node3D = $Display

var _message_until: int = 0


func _ready() -> void:
	$Lever.pulled.connect(_on_lever_pulled)
	_build_display()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() < _message_until:
		return
	if not is_open():
		_screen.text = _closed_text()
		_screen.modulate = Color(1, 0.75, 0.4)
	elif game.upgrades.unowned_cards().is_empty():
		_screen.text = "SOLD OUT"
	else:
		_screen.text = "RANDOM CARD\n%d gold\n\nPull the lever!" % price
		_screen.modulate = Color.WHITE if game.can_afford(price) else Color(1, 0.5, 0.45)


func _on_lever_pulled() -> void:
	if game.is_over:
		return
	if not is_open():
		_say(_closed_text())
		return
	var choices := game.upgrades.unowned_cards()
	if choices.is_empty():
		_say("SOLD OUT")
		return
	if not game.spend(price):
		_say("NOT ENOUGH\nGOLD\n\n%d needed" % price)
		return
	price += price_step
	var card: Card = choices.pick_random()
	# Pop it out of the slot towards the player.
	station.spawn_card(card, _output.global_position, global_basis.z * 1.2 + Vector3.UP * 0.8)
	_say("YOU GOT\n%s!" % card.title.to_upper())
	_build_display()


func is_open() -> bool:
	return game.wave >= opens_at_wave


func _closed_text() -> String:
	return "CLOSED\n\nOpens at\nwave %d" % opens_at_wave


func _say(text: String) -> void:
	_screen.text = text
	_screen.modulate = Color(1, 0.9, 0.4)
	_message_until = Time.get_ticks_msec() + MESSAGE_TIME_MSEC


## Fills the window with the cards still for sale.
func _build_display() -> void:
	for child in _display.get_children():
		child.queue_free()
	var cards := game.upgrades.unowned_cards()
	for i in mini(cards.size(), 12):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.1, 0.006)
		var material := StandardMaterial3D.new()
		material.albedo_color = cards[i].color
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3((i % 3 - 1) * 0.13, 0.27 - (i / 3) * 0.18, 0)
		instance.rotation.x = -0.15
		_display.add_child(instance)
