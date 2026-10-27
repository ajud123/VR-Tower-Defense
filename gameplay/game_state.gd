class_name GameState
extends Node
## Lives, gold and wave progress for one game. Lives on the gameplay scene,
## so reloading the scene starts a fresh game.

signal ended(won: bool)

@export var starting_lives: int = 20
@export var starting_gold: int = 200
## The player's cards. Anything with access to the game reaches them here.
@export var upgrades: Upgrades

var lives: int
var gold: int
## The wave currently running or last finished; 0 before the first one.
var wave: int = 0
var total_waves: int = 0
## Name of the wave running, or of the next one during the countdown.
var wave_name: String = ""
## Seconds until the next wave starts, or a negative number while a wave runs.
var next_wave_in: float = -1.0
## Gold paid for clearing the last wave, or 0 before any wave is cleared.
var last_wave_bonus: int = 0
var is_over: bool = false
var won: bool = false


func _ready() -> void:
	lives = starting_lives
	gold = starting_gold


func can_afford(amount: int) -> bool:
	return gold >= amount


## Takes the gold if there is enough. Returns whether it did.
func spend(amount: int) -> bool:
	if is_over or gold < amount:
		return false
	gold -= amount
	return true


func earn(amount: int) -> void:
	gold += amount


func lose_life(amount: int = 1) -> void:
	if is_over:
		return
	lives = maxi(lives - amount, 0)
	if lives == 0:
		_end(false)


func win() -> void:
	_end(true)


func _end(player_won: bool) -> void:
	if is_over:
		return
	is_over = true
	won = player_won
	ended.emit(player_won)
