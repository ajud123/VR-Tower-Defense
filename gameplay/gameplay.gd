extends Node3D
## Gameplay scene: the park, the picnic table and the board on top of it.

const MAIN_MENU_SCENE := "res://main_menu/main_menu.tscn"

@onready var _banner: Label3D = $PicnicTable/Banner


func _on_game_ended(won: bool) -> void:
	get_tree().call_group("enemies", "queue_free")
	_banner.text = "YOU WIN!" if won else "GAME OVER"
	_banner.modulate = Color(1, 0.85, 0.3) if won else Color(1, 0.35, 0.3)
	_banner.show()


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
