extends Node3D
## Gameplay scene: the park, the picnic table and the board on top of it.
## The status sign shows the win or loss.

const MAIN_MENU_SCENE := "res://main_menu/main_menu.tscn"


func _on_game_ended(_won: bool) -> void:
	get_tree().call_group("enemies", "queue_free")


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
