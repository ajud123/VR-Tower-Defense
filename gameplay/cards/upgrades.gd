class_name Upgrades
extends Node
## Which cards the player owns and which are active, and the combined effect
## of the active ones. Towers and enemies ask this for their stat modifiers.

signal changed

const SLOT_COUNT := 3

## Every card .tres in here can come out of the vending machine.
@export_dir var pool_dir: String = "res://gameplay/cards/pool"

## Cards the player has, in the order they got them.
var owned: Array[Card] = []
## The active slots; empty slots are null.
var slots: Array[Card] = []

var _pool: Array[Card] = []


func _init() -> void:
	slots.resize(SLOT_COUNT)


## All cards that exist, loaded from pool_dir on first use.
func get_pool() -> Array[Card]:
	if _pool.is_empty():
		for file in ResourceLoader.list_directory(pool_dir):
			var card := load(pool_dir.path_join(file)) as Card
			if card:
				_pool.append(card)
	return _pool


func unowned_cards() -> Array[Card]:
	return get_pool().filter(func(card: Card) -> bool: return card not in owned)


func add_card(card: Card) -> void:
	if card not in owned:
		owned.append(card)
		changed.emit()


func is_active(card: Card) -> bool:
	return card in slots


func active_count() -> int:
	return SLOT_COUNT - slots.count(null)


## Puts a card into a slot. If it came from another slot, the two swap;
## if it came from storage, whatever was in the slot goes back to storage.
func equip(card: Card, slot: int) -> void:
	var previous := slots.find(card)
	if previous == slot:
		return
	if previous != -1:
		slots[previous] = slots[slot]
	slots[slot] = card
	changed.emit()


func unequip(card: Card) -> void:
	var slot := slots.find(card)
	if slot != -1:
		slots[slot] = null
		changed.emit()


## Product of every active multiplier for "<group>.<stat>" and "<kind>.<stat>".
func multiplier(group: String, kind: String, stat: String) -> float:
	var result := 1.0
	for card in slots:
		if card:
			result *= card.multipliers.get(group + "." + stat, 1.0)
			result *= card.multipliers.get(kind + "." + stat, 1.0)
	return result


## Sum of every active bonus for "<group>.<stat>" and "<kind>.<stat>".
func bonus(group: String, kind: String, stat: String) -> float:
	var result := 0.0
	for card in slots:
		if card:
			result += card.bonuses.get(group + "." + stat, 0.0)
			result += card.bonuses.get(kind + "." + stat, 0.0)
	return result
