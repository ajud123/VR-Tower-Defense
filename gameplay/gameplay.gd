extends Node3D
## Gameplay scene: the park, the picnic table and the board on top of it.
## The status sign shows the win or loss.

@onready var _game: GameState = $Game
@onready var _start_button: PushButton = $PicnicTable/StartButton

var _restarting: bool = false


func _on_game_ended(_won: bool) -> void:
	get_tree().call_group("enemies", "queue_free")


func _on_start_button_pressed() -> void:
	if _restarting:
		return
	_game.start()


func _on_restart_button_pressed() -> void:
	if _restarting:
		return
	_restarting = true
	var pop_tween: Tween = _start_button.unpress()
	if pop_tween:
		await pop_tween.finished
	else:
		await get_tree().create_timer(0.15).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()
