@tool
class_name Board
extends Node3D
## The tabletop battlefield: a grid of tiles with one enemy path winding
## through it. Builds its own visuals from the exported layout, so tweak the
## numbers in the inspector and the board rebuilds live in the editor.
## Tiles, castle and portal pad are Kenney models (assets/kenney/); path
## tiles are picked and turned to match where the path goes.
##
## The node's origin is the centre of the board's underside; set it straight
## onto the table top. Cell (0, 0) is the far-left corner as seen by the player.

const BORDER := 0.04
const BASE_THICKNESS := 0.035
## Kenney tiles are 1 x 0.2 x 1 with the path floor at half height, so these
## are fractions of the tile size.
const TILE_HEIGHT := 0.2
const PATH_SINK := 0.1

const TD_KIT := "res://assets/kenney/tower_defense/"
const CASTLE_KIT := "res://assets/kenney/castle/"
const GRASS_TILE := preload(TD_KIT + "tile.glb")
## Path tiles, with the sides their path opens to when not rotated.
const PATH_TILES := {
	"straight": [preload(TD_KIT + "tile-straight.glb"), [Vector2i(0, 1), Vector2i(0, -1)]],
	"corner": [preload(TD_KIT + "tile-corner-round.glb"), [Vector2i(1, 0), Vector2i(0, 1)]],
	"end": [preload(TD_KIT + "tile-end-round.glb"), [Vector2i(0, 1)]],
	"spawn": [preload(TD_KIT + "tile-spawn-end.glb"), [Vector2i(0, 1)]],
}
const CASTLE_PARTS := [
	preload(CASTLE_KIT + "tower-square-base.glb"),
	preload(CASTLE_KIT + "tower-square-top-roof-high.glb"),
]
## Castle size relative to a tile.
const CASTLE_SCALE := 0.7

@export var columns: int = 12:
	set(value):
		columns = maxi(value, 2)
		_queue_rebuild()
@export var rows: int = 8:
	set(value):
		rows = maxi(value, 2)
		_queue_rebuild()
## Edge length of one tile in metres.
@export var tile_size: float = 0.08:
	set(value):
		tile_size = maxf(value, 0.01)
		_queue_rebuild()
## Corners of the enemy path in grid cells, from spawn to base. Consecutive
## corners must share a row or a column.
@export var path_corners: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(3, 1), Vector2i(3, 5), Vector2i(6, 5),
	Vector2i(6, 2), Vector2i(9, 2), Vector2i(9, 6), Vector2i(11, 6),
]:
	set(value):
		path_corners = value
		_queue_rebuild()

@export_group("Colors")
@export var frame_color: Color = Color(0.3, 0.2, 0.12):
	set(value):
		frame_color = value
		_queue_rebuild()

## Height of the grass surface above the node's origin.
var surface_height: float:
	get:
		return BASE_THICKNESS + TILE_HEIGHT * tile_size

var _path_cells: Array[Vector2i] = []
var _path_lookup: Dictionary = {}
var _towers: Dictionary = {}  # Vector2i -> Node3D
var _visuals: Node3D
var _enemy_path: Path3D
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


## Centre of a cell's top surface, in board-local space.
func cell_to_local(cell: Vector2i) -> Vector3:
	var top := surface_height - (PATH_SINK * tile_size if is_path_cell(cell) else 0.0)
	return Vector3(
		(cell.x - (columns - 1) * 0.5) * tile_size,
		top,
		(cell.y - (rows - 1) * 0.5) * tile_size
	)


func cell_to_world(cell: Vector2i) -> Vector3:
	return to_global(cell_to_local(cell))


## The cell under a world position. May be out of bounds; check with is_in_bounds().
func world_to_cell(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(
		roundi(local.x / tile_size + (columns - 1) * 0.5),
		roundi(local.z / tile_size + (rows - 1) * 0.5)
	)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func is_path_cell(cell: Vector2i) -> bool:
	return _path_lookup.has(cell)


## Whether a tower may go on this cell: on the board, off the path, empty.
func is_buildable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_path_cell(cell) and not _towers.has(cell)


## Puts a tower on the board, standing on the given cell.
func place_tower(cell: Vector2i, tower: Node3D) -> void:
	assert(is_buildable(cell), "Cell %s is not buildable" % cell)
	_towers[cell] = tower
	add_child(tower)
	tower.position = cell_to_local(cell)
	tower.tree_exited.connect(func() -> void: _towers.erase(cell))


## The tower standing on a cell, or null.
func tower_at(cell: Vector2i) -> Node3D:
	return _towers.get(cell)


## How many towers of a kind ("archer", ...) are on the board.
func count_towers(kind: String) -> int:
	return _towers.values().filter(func(tower: Node3D) -> bool: return tower.get("kind") == kind).size()


## Every path cell in walking order, spawn first.
func get_path_cells() -> Array[Vector2i]:
	return _path_cells.duplicate()


## The route enemies walk, running along the path tiles' surface.
func get_enemy_path() -> Path3D:
	return _enemy_path


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _visuals:
		_visuals.queue_free()
	if _enemy_path:
		_enemy_path.queue_free()
	_trace_path()

	# Built nodes have no owner, so they show in the editor but are never
	# saved into the scene file.
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_build_frame()
	_build_tiles()
	_build_spawn_portal()
	_build_base()

	_enemy_path = Path3D.new()
	_enemy_path.name = "EnemyPath"
	_enemy_path.curve = Curve3D.new()
	for corner in path_corners:
		_enemy_path.curve.add_point(cell_to_local(corner))
	add_child(_enemy_path)


func _trace_path() -> void:
	_path_cells.clear()
	_path_lookup.clear()
	if path_corners.is_empty():
		return
	_add_path_cell(path_corners[0])
	for i in range(1, path_corners.size()):
		var from := path_corners[i - 1]
		var to := path_corners[i]
		if from.x != to.x and from.y != to.y:
			push_warning("Board path corners %s and %s are not in a straight line" % [from, to])
			continue
		var step := (to - from).sign()
		var cell := from
		while cell != to:
			cell += step
			_add_path_cell(cell)


func _add_path_cell(cell: Vector2i) -> void:
	if not _path_lookup.has(cell):
		_path_lookup[cell] = true
		_path_cells.append(cell)


func _build_frame() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(columns * tile_size + BORDER * 2.0, BASE_THICKNESS, rows * tile_size + BORDER * 2.0)
	mesh.material = _material(frame_color)
	_add_mesh(mesh, Vector3(0, BASE_THICKNESS * 0.5, 0))


func _build_tiles() -> void:
	var tiles := Node3D.new()
	tiles.name = "Tiles"
	_visuals.add_child(tiles)
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			var scene: PackedScene = GRASS_TILE
			var turns := 0
			if is_path_cell(cell):
				var piece := _path_piece(cell)
				scene = PATH_TILES[piece][0]
				turns = _turns_to_fit(PATH_TILES[piece][1], _path_openings(cell))
			var tile: Node3D = scene.instantiate()
			var center := cell_to_local(cell)
			var basis := Basis(Vector3.UP, turns * PI * 0.5).scaled(Vector3.ONE * tile_size)
			tile.transform = Transform3D(basis, Vector3(center.x, BASE_THICKNESS, center.z))
			tiles.add_child(tile)


## The directions (in cells) the path leaves this path cell in.
func _path_openings(cell: Vector2i) -> Array[Vector2i]:
	var openings: Array[Vector2i] = []
	var i := _path_cells.find(cell)
	if i > 0:
		openings.append(_path_cells[i - 1] - cell)
	if i < _path_cells.size() - 1:
		openings.append(_path_cells[i + 1] - cell)
	return openings


func _path_piece(cell: Vector2i) -> String:
	var openings := _path_openings(cell)
	if cell == _path_cells[0]:
		return "spawn"
	if openings.size() < 2:
		return "end"
	return "straight" if openings[0] == -openings[1] else "corner"


## How many quarter turns around +Y make a tile's openings match `wanted`.
func _turns_to_fit(openings: Array, wanted: Array[Vector2i]) -> int:
	for turns in 4:
		var turned := openings.map(func(side: Vector2i) -> Vector2i: return _turn(side, turns))
		if turned.size() == wanted.size() and wanted.all(func(side: Vector2i) -> bool: return side in turned):
			return turns
	return 0


## A grid direction turned by quarter turns around +Y (+x goes to -z).
func _turn(side: Vector2i, turns: int) -> Vector2i:
	for i in turns:
		side = Vector2i(side.y, -side.x)
	return side


func _build_spawn_portal() -> void:
	if _path_cells.is_empty():
		return
	var ring := TorusMesh.new()
	ring.inner_radius = tile_size * 0.28
	ring.outer_radius = tile_size * 0.42
	var material := _material(Color(0.55, 0.2, 0.85))
	material.emission_enabled = true
	material.emission = Color(0.6, 0.2, 1.0)
	material.emission_energy_multiplier = 1.5
	ring.material = material

	# Stand the ring upright, facing along the first stretch of path.
	var start := _path_cells[0]
	var heading := Vector3.RIGHT
	if _path_cells.size() > 1:
		heading = cell_to_local(_path_cells[1]) - cell_to_local(start)
		heading.y = 0.0
	var facing := Basis.looking_at(heading.normalized()) * Basis(Vector3.RIGHT, PI * 0.5)
	var origin := cell_to_local(start) + Vector3(0, ring.outer_radius, 0)
	_add_mesh(ring, origin, facing)


func _build_base() -> void:
	if _path_cells.is_empty():
		return
	var end := cell_to_local(_path_cells[-1])
	var height := 0.0
	for part: PackedScene in CASTLE_PARTS:
		var piece: Node3D = part.instantiate()
		piece.scale = Vector3.ONE * tile_size * CASTLE_SCALE
		piece.position = end + Vector3(0, height, 0)
		_visuals.add_child(piece)
		height += _height_of(piece)


## Height of a model's meshes, in the model's parent's space.
func _height_of(model: Node3D) -> float:
	var top := 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.get_aabb()
		top = maxf(top, (box.position.y + box.size.y) * mesh.transform.basis.get_scale().y)
	return top * model.scale.y


func _add_mesh(mesh: Mesh, origin: Vector3, orientation := Basis()) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = Transform3D(orientation, origin)
	_visuals.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
