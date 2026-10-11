extends Node3D
## The sign across the table: lives, gold and wave progress.

@export var game: GameState

@onready var _text: Label3D = $Text


func _process(_delta: float) -> void:
	var status: String
	if game.is_over:
		status = "YOU WIN!" if game.won else "GAME OVER"
	elif game.next_wave_in >= 0.0 and game.last_wave_bonus > 0:
		status = "Wave cleared: +%d gold      Next wave in %d" % [
			game.last_wave_bonus, ceili(game.next_wave_in)
		]
	elif game.next_wave_in >= 0.0:
		status = "Next wave in %d" % ceili(game.next_wave_in)
	else:
		status = "Wave in progress"
	_text.text = "Lives %d      Gold %d      Wave %d / %d\n%s" % [
		game.lives, game.gold, game.wave, game.total_waves, status
	]
