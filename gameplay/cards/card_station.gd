class_name CardStation
extends Node3D
## The card area on the table: three active slots in front, storage behind.
## Owns every card the player has bought (as CardViews, wherever they are in
## the world) and lays out the ones put into storage or a slot. Upgrades
## decides which cards are active.

const CARD_VIEW := preload("res://gameplay/cards/card_view.tscn")
## Slot number meaning "storage" for place().
const STORAGE := -1
const STORAGE_COLUMNS := 5
const STORAGE_SPACING := Vector2(0.066, 0.095)
## How close to a slot a VR-dropped card has to be to go into it.
const SNAP_DISTANCE := 0.1
## The storage mat's extent in station space, for VR drops.
const STORAGE_AREA := AABB(Vector3(-0.18, -0.02, -0.29), Vector3(0.36, 0.2, 0.36))

@export var game: GameState

@onready var _slots: Array[Node3D] = [$Slots/Slot1, $Slots/Slot2, $Slots/Slot3]
@onready var _storage: Node3D = $Storage
@onready var _info: Label3D = $Info

var _views: Dictionary = {}  # Card -> CardView
var _stored: Array[CardView] = []


func _ready() -> void:
	game.upgrades.changed.connect(_layout)


func _process(_delta: float) -> void:
	_update_info()


## Makes the CardView for a newly bought card and throws it into the world.
func spawn_card(card: Card, at: Vector3, velocity: Vector3) -> CardView:
	var view: CardView = CARD_VIEW.instantiate()
	view.card = card
	view.station = self
	add_child(view)
	_views[card] = view
	game.upgrades.add_card(card)
	view.drop(at, velocity)
	return view


## Takes a card out of storage or its slot, e.g. because it's picked up.
func take(view: CardView) -> void:
	_stored.erase(view)
	game.upgrades.unequip(view.card)
	_layout()


## Puts a card into a slot (0-2) or into STORAGE. Whatever was in the slot
## goes to storage.
func place(view: CardView, slot: int) -> bool:
	_stored.erase(view)
	if slot == STORAGE:
		game.upgrades.unequip(view.card)
		_stored.append(view)
	else:
		var occupant: Card = game.upgrades.slots[slot]
		if occupant and occupant != view.card:
			_stored.append(_views[occupant])
		game.upgrades.equip(view.card, slot)
	_layout()
	return true


## VR drop: into the nearest slot or storage if the card is over one,
## otherwise it falls where it is.
func put_down(view: CardView) -> void:
	var slot := _nearest_slot(view.global_position)
	if slot != -1:
		place(view, slot)
	elif STORAGE_AREA.has_point(to_local(view.global_position)):
		place(view, STORAGE)
	else:
		view.drop(view.global_position)


## Which slot a card is in, or -1.
func slot_of(view: CardView) -> int:
	return game.upgrades.slots.find(view.card)


func _nearest_slot(world_position: Vector3) -> int:
	var best := -1
	var best_distance := SNAP_DISTANCE
	for i in _slots.size():
		var distance := _slots[i].global_position.distance_to(world_position)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _layout() -> void:
	for i in _slots.size():
		var card: Card = game.upgrades.slots[i]
		if card:
			_views[card].settle(CardView.State.ACTIVE, _slots[i].global_transform)
	for i in _stored.size():
		var offset := Vector3(
			(i % STORAGE_COLUMNS - (STORAGE_COLUMNS - 1) * 0.5) * STORAGE_SPACING.x,
			(i / STORAGE_COLUMNS) * STORAGE_SPACING.y,
			0.0
		)
		_stored[i].settle(CardView.State.STORED, _storage.global_transform * Transform3D(Basis(), offset))


## The how-to printed on the empty mat only shows until the first wave is
## cleared.
func _update_info() -> void:
	var first_wave_done := game.wave > 1 or (game.wave == 1 and game.next_wave_in >= 0.0)
	_info.visible = not first_wave_done
	if _info.visible:
		_info.text = "CARDS  %d/%d active\nPick up cards and put them in the gold slots\nCards come from the machine behind you (opens at wave 2)" % [
			game.upgrades.active_count(), Upgrades.SLOT_COUNT
		]
