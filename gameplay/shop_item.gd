extends StaticBody3D
## A tower for sale on the shop tray. Click it (or point + trigger) to pick
## it and then click a tile, or in VR grab it with the grip and drop it on a
## tile. The shop never runs out.

const HOVER_LIFT := 0.012
const PICKED_COLOR := Color(1.0, 0.85, 0.3)
const TOO_EXPENSIVE_COLOR := Color(1.0, 0.45, 0.4)

@export var tower_scene: PackedScene
@export var placer: TowerPlacer

@onready var _label: Label3D = $Label3D

var _display: Tower
var _hover_count: int = 0


func _ready() -> void:
	_display = tower_scene.instantiate()
	_display.make_preview(false)
	_display.upgrades = placer.game.upgrades
	add_child(_display)


func _process(_delta: float) -> void:
	# Cards can change the price, so keep the label current.
	var cost := _display.get_cost()
	_label.text = "%s\n%d gold" % [_display.display_name, cost]
	var picked := placer.selected == tower_scene
	if picked:
		_label.modulate = PICKED_COLOR
	elif placer.game.can_afford(cost):
		_label.modulate = Color.WHITE
	else:
		_label.modulate = TOO_EXPENSIVE_COLOR
	_display.position.y = HOVER_LIFT if picked or _hover_count > 0 else 0.0


func is_hovered() -> bool:
	return _hover_count > 0


func is_picked() -> bool:
	return placer.selected == tower_scene


func describe() -> String:
	return _display.describe(placer.board.tile_size)


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	placer.select(tower_scene)


## VR grab: hands the hand the placer, which carries the tower until release().
func grab(hand: Node3D) -> Object:
	return placer if placer.begin_carry(tower_scene, hand) else null


func hover_enter() -> void:
	_hover_count += 1


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
