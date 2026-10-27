extends Node3D
## The sign across the table: lives, gold and wave as icons and numbers,
## and below them what's happening (next wave countdown, win or lose).

const ROW_HEIGHT := 0.28
const ICON_SIZE := 0.045
const WIN_COLOR := Color(1, 0.85, 0.3)
const LOSE_COLOR := Color(1, 0.35, 0.3)

@export var game: GameState

@onready var _text: Label3D = $Text

var _lives: Label3D
var _gold: Label3D
var _wave: Label3D


func _ready() -> void:
	_lives = _add_counter("health", Icons.stat_color("health"), -0.27)
	_gold = _add_counter("gold", Icons.stat_color("reward"), -0.04)
	_wave = _add_counter("wave", Color.WHITE, 0.17)


func _process(_delta: float) -> void:
	_lives.text = str(game.lives)
	_gold.text = str(game.gold)
	_wave.text = "%d/%d" % [game.wave, game.total_waves]
	_text.modulate = Color.WHITE
	_text.font_size = 36
	if game.is_over:
		_text.text = "YOU WIN!" if game.won else "GAME OVER"
		_text.modulate = WIN_COLOR if game.won else LOSE_COLOR
		_text.font_size = 56
	elif game.next_wave_in >= 0.0 and game.last_wave_bonus > 0:
		_text.text = "Wave cleared: +%d gold      Next wave in %d" % [
			game.last_wave_bonus, ceili(game.next_wave_in)
		]
	elif game.next_wave_in >= 0.0:
		_text.text = "Next wave in %d" % ceili(game.next_wave_in)
	else:
		_text.text = "Wave in progress"


## An icon with a number to its right, on the top row of the sign.
func _add_counter(icon_key: String, color: Color, x: float) -> Label3D:
	var icon := Icons.sprite(icon_key, ICON_SIZE, color)
	icon.position = Vector3(x, ROW_HEIGHT, 0.01)
	add_child(icon)
	var label := Label3D.new()
	label.pixel_size = 0.0008
	label.font_size = 52
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector3(x + ICON_SIZE * 0.7, ROW_HEIGHT, 0.01)
	add_child(label)
	return label
