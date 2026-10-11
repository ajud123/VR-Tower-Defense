extends Node3D
## Title screen. The big button starts a game.

const GAMEPLAY_SCENE := "res://gameplay/gameplay.tscn"


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)
