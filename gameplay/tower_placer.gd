class_name TowerPlacer
extends StaticBody3D
## Puts towers from the shop onto the board, two ways:
## - Pick: interact with a shop tower to select it, then interact with a tile
##   (desktop left click, or VR laser + trigger). Right click cancels.
## - Carry (VR): grab a shop tower with the grip and let go above a tile.
##
## Lives on the board as the clickable surface over its grid, and marks the
## tile a tower would land on: green if it can be built there, red if not.

## How high above the board a carried tower can be let go and still land.
const DROP_HEIGHT := 0.3
## Where a carried tower hangs relative to the hand holding it.
const CARRY_OFFSET := Vector3(0, -0.07, 0)
const NO_CELL := Vector2i(-1, -1)
const BUILDABLE_COLOR := Color(0.3, 1.0, 0.4, 0.55)
const BLOCKED_COLOR := Color(1.0, 0.25, 0.2, 0.55)

@export var board: Board
@export var game: GameState

## The tower picked in the shop and waiting for a tile, or null.
var selected: PackedScene

var _carry_scene: PackedScene
var _carry_hand: Node3D
## See-through copy of the selected or carried tower.
var _ghost: Tower
## Where a pointer last hit the board surface, or null when none is on it.
var _surface_point: Variant = null
var _hover_count: int = 0
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _range_ring: MeshInstance3D


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(board.columns * board.tile_size, 0.02, board.rows * board.tile_size)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = board.surface_height - 0.01
	add_child(collision)
	_build_markers()
	game.ended.connect(func(_won: bool) -> void:
		cancel()
		_end_carry()
	)


func _process(_delta: float) -> void:
	var cell := NO_CELL
	if _carry_hand:
		if not is_instance_valid(_carry_hand):
			_end_carry()
			return
		_ghost.visible = true
		_ghost.global_basis = Basis.IDENTITY
		_ghost.global_position = _carry_hand.global_position + CARRY_OFFSET
		cell = _cell_under(_ghost.global_position)
	elif selected and _surface_point != null:
		cell = board.world_to_cell(_surface_point)
		if not board.is_in_bounds(cell):
			cell = NO_CELL
		else:
			_ghost.position = board.cell_to_local(cell)
		_ghost.visible = cell != NO_CELL
	elif _ghost:
		_ghost.visible = false
	_update_markers(cell)


func _unhandled_input(event: InputEvent) -> void:
	if selected and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel()
		get_viewport().set_input_as_handled()


## Picks a tower to build. Picking the same one again puts it back.
func select(tower_scene: PackedScene) -> void:
	if _carry_hand or game.is_over:
		return
	if tower_scene == selected:
		cancel()
		return
	selected = tower_scene
	_set_ghost(tower_scene)


func cancel() -> void:
	selected = null
	if not _carry_hand:
		_set_ghost(null)


## Starts carrying a tower in a VR hand. Returns false if one is already
## being carried.
func begin_carry(tower_scene: PackedScene, hand: Node3D) -> bool:
	if _carry_hand or game.is_over:
		return false
	selected = null
	_carry_scene = tower_scene
	_carry_hand = hand
	_set_ghost(tower_scene)
	return true


## Lets go of the carried tower: it's built if it's over a free tile, and
## goes back to the shop otherwise.
func release() -> void:
	if not _carry_hand:
		return
	_try_build(_carry_scene, _cell_under(_ghost.global_position))
	_end_carry()


# Called by InteractionRay: the board surface is clickable.
func interact(point: Vector3 = Vector3.ZERO) -> void:
	if selected and _try_build(selected, board.world_to_cell(point)):
		cancel()


func hover_enter() -> void:
	_hover_count += 1


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	if _hover_count == 0:
		_surface_point = null


func hover_update(point: Vector3) -> void:
	_surface_point = point


func _end_carry() -> void:
	if not _carry_hand:
		return
	_carry_hand = null
	_carry_scene = null
	_set_ghost(null)


func _can_build(cell: Vector2i) -> bool:
	return not game.is_over and board.is_buildable(cell) and game.can_afford(_ghost.get_cost())


func _try_build(tower_scene: PackedScene, cell: Vector2i) -> bool:
	if not _can_build(cell) or not game.spend(_ghost.get_cost()):
		return false
	var tower: Tower = tower_scene.instantiate()
	tower.upgrades = game.upgrades
	board.place_tower(cell, tower)
	return true


## The tile directly below a carried tower, or NO_CELL if it's off the board
## or held too high.
func _cell_under(world_position: Vector3) -> Vector2i:
	var cell := board.world_to_cell(world_position)
	var height := board.to_local(world_position).y - board.surface_height
	if board.is_in_bounds(cell) and height > -0.05 and height < DROP_HEIGHT:
		return cell
	return NO_CELL


func _set_ghost(tower_scene: PackedScene) -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	if tower_scene:
		_ghost = tower_scene.instantiate()
		_ghost.make_preview(true)
		_ghost.upgrades = game.upgrades
		_ghost.visible = false
		add_child(_ghost)


func _update_markers(cell: Vector2i) -> void:
	var shown := cell != NO_CELL and _ghost != null
	_marker.visible = shown
	_range_ring.visible = shown
	if not shown:
		return
	_marker_material.albedo_color = BUILDABLE_COLOR if _can_build(cell) else BLOCKED_COLOR
	var spot := board.cell_to_local(cell) + Vector3.UP * 0.003
	_marker.position = spot
	_range_ring.position = spot
	var reach := _ghost.get_range()
	_range_ring.scale = Vector3(reach, 1.0, reach)


func _build_markers() -> void:
	_marker_material = _overlay_material(BUILDABLE_COLOR)
	var tile := BoxMesh.new()
	tile.size = Vector3(board.tile_size * 0.96, 0.004, board.tile_size * 0.96)
	tile.material = _marker_material
	_marker = MeshInstance3D.new()
	_marker.mesh = tile
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)

	var ring := CylinderMesh.new()
	ring.top_radius = 1.0
	ring.bottom_radius = 1.0
	ring.height = 0.002
	ring.radial_segments = 48
	ring.material = _overlay_material(Color(1, 1, 1, 0.25))
	_range_ring = MeshInstance3D.new()
	_range_ring.mesh = ring
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.visible = false
	add_child(_range_ring)


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
