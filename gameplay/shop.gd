extends Node3D
## The tower shop tray. A board behind the towers shows the stats of
## whichever tower is hovered, or failing that, the one picked and waiting
## to be built.

const BOARD_POSITION := Vector3(0.125, 0.0, 0.0)
## Turned to face the player on the bench.
const BOARD_YAW_DEGREES := -70.0
const PANEL_SIZE := Vector2(0.36, 0.17)
const PANEL_HEIGHT := 0.27
## Stats fill the board left to right, three per line.
const COLUMNS := 3
const MAX_ROWS := 9
const ICON_SIZE := 0.026
const INK := Color(0.95, 0.93, 0.85)

var _header: Label3D
var _row_icons: Array[Sprite3D] = []
var _row_labels: Array[Label3D] = []
var _shown: Tower
var _shown_rows: Array[Dictionary] = []


func _ready() -> void:
	_build_board()


func _process(_delta: float) -> void:
	var focus: Node = null
	for item in get_children():
		if item.has_method("get_tower") and item.is_hovered():
			focus = item
	if focus == null:
		for item in get_children():
			if item.has_method("get_tower") and item.is_picked():
				focus = item
	var tower: Tower = focus.get_tower() if focus else null
	var rows: Array[Dictionary] = []
	if tower:
		rows = tower.stat_rows(focus.placer.board.tile_size)
	if tower == _shown and rows == _shown_rows:
		return
	_shown = tower
	_shown_rows = rows
	_header.text = tower.display_name.to_upper() if tower else "SHOP"
	_header.font_size = 40 if tower else 64
	for i in MAX_ROWS:
		var used := i < rows.size()
		_row_icons[i].visible = used
		_row_labels[i].visible = used
		if used:
			_row_icons[i].texture = Icons.texture(rows[i].icon)
			_row_icons[i].modulate = Icons.stat_color(rows[i].icon)
			_row_labels[i].text = rows[i].text


func _build_board() -> void:
	var board := Node3D.new()
	board.position = BOARD_POSITION
	board.rotation_degrees.y = BOARD_YAW_DEGREES
	add_child(board)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	for side in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.015, PANEL_HEIGHT, 0.015)
		post.material = wood
		var post_mesh := MeshInstance3D.new()
		post_mesh.mesh = post
		post_mesh.position = Vector3(side * (PANEL_SIZE.x * 0.5 - 0.01), PANEL_HEIGHT * 0.5, -0.01)
		board.add_child(post_mesh)

	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color(0.13, 0.15, 0.14)
	var panel := BoxMesh.new()
	panel.size = Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.01)
	panel.material = slate
	var panel_mesh := MeshInstance3D.new()
	panel_mesh.mesh = panel
	panel_mesh.position.y = PANEL_HEIGHT
	board.add_child(panel_mesh)

	var face := Node3D.new()
	face.position = Vector3(0, PANEL_HEIGHT, 0.0055)
	board.add_child(face)
	_header = _label("SHOP", 64, Vector3(0, 0.058, 0))
	face.add_child(_header)
	for i in MAX_ROWS:
		var at := Vector3(-0.15 + (i % COLUMNS) * 0.115, 0.018 - (i / COLUMNS) * 0.04, 0)
		var icon := Icons.sprite("damage", ICON_SIZE)
		icon.position = at
		icon.visible = false
		face.add_child(icon)
		_row_icons.append(icon)
		var label := _label("", 36, at + Vector3(ICON_SIZE * 0.85, 0, 0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.visible = false
		face.add_child(label)
		_row_labels.append(label)


func _label(text: String, font_size: int, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0006
	label.outline_size = 0
	label.modulate = INK
	label.position = at
	return label
