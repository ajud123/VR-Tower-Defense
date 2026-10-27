class_name Hammer
extends StaticBody3D
## The demolition hammer: smash a tower to sell it for part of what it cost.
## It breaks into pieces and the gold pops out.
##
## VR: grab it (grip), swing it down onto a tower. Let go anywhere and it
## goes back to its spot on the table.
## Desktop: click it to pick it up, then click a tower. Right click puts it back.

## Fraction of a tower's price paid back when it's smashed.
const REFUND := 0.7
## How fast the head has to move to count as a hit, in m/s.
const SMASH_SPEED := 0.6
const COOLDOWN_MSEC := 300
const RETURN_TIME := 0.4
## How the hammer sits in a hand: handle pointing forward, head faces up/down.
const HAND_OFFSET := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.03))
## Height above the board's surface a tower can be hit at.
const TOWER_HEIGHT := 0.14
const DEBRIS_LIFETIME := 1.4
const GOLD_COLOR := Color(1.0, 0.82, 0.25)
const DUST_COLOR := Color(0.8, 0.75, 0.7, 0.8)
const NO_CELL := Vector2i(-1, -1)

@export var board: Board
@export var game: GameState

@onready var _head: Node3D = $Head

var _holder: Node3D
var _hold_offset: Transform3D
var _rest: Transform3D
var _last_head: Vector3
var _next_smash_msec: int = 0
var _return_tween: Tween


func _ready() -> void:
	_rest = global_transform


func _physics_process(delta: float) -> void:
	if not _holder:
		return
	if not is_instance_valid(_holder):
		_go_home()
		return
	global_transform = _holder.global_transform * _hold_offset
	var head := _head.global_position
	var speed := head.distance_to(_last_head) / delta
	_last_head = head
	if speed >= SMASH_SPEED and Time.get_ticks_msec() >= _next_smash_msec:
		var cell := _tower_cell_at(head)
		if cell != NO_CELL:
			smash(cell)


# VR grip.
func grab(hand: Node3D) -> Object:
	return self if pick_up(hand, HAND_OFFSET) else null


# VR grip let go.
func release() -> void:
	_go_home()


## Desktop pick up; also used by grab(). It then follows `holder`.
func pick_up(holder: Node3D, offset: Transform3D = HAND_OFFSET) -> bool:
	if _holder:
		return false
	if _return_tween:
		_return_tween.kill()
	_holder = holder
	_hold_offset = offset
	collision_layer = 0
	global_transform = _holder.global_transform * _hold_offset
	_last_head = _head.global_position
	return true


## Desktop put down (right click). Wherever it is, it goes home.
func drop(_at: Vector3 = Vector3.ZERO, _velocity: Vector3 = Vector3.ZERO) -> void:
	_go_home()


## Desktop click while holding it: smashes the first tower along the line
## from `from` to `to`. Returns whether it hit one.
func use_along(from: Vector3, to: Vector3) -> bool:
	var steps := ceili(from.distance_to(to) / 0.01)
	for i in steps + 1:
		var cell := _tower_cell_at(from.lerp(to, float(i) / maxf(steps, 1)))
		if cell != NO_CELL:
			smash(cell)
			return true
	return false


# Pointing at the hammer does nothing by itself; this makes rays target it.
func interact(_point: Vector3 = Vector3.ZERO) -> void:
	pass


## Breaks the tower on `cell` and pays back part of its price.
func smash(cell: Vector2i) -> void:
	var tower := board.tower_at(cell) as Tower
	if tower == null:
		return
	_next_smash_msec = Time.get_ticks_msec() + COOLDOWN_MSEC
	var refund := roundi(tower.paid * REFUND)
	game.earn(refund)
	var world := board.get_parent()
	var at := tower.global_position + Vector3.UP * 0.04
	Effects.burst(world, at, DUST_COLOR, 20, 0.014, 0.12, 0.6)
	Effects.burst(world, at + Vector3.UP * 0.03, GOLD_COLOR, 16, 0.008, 0.2, 0.6)
	_show_refund(world, at + Vector3.UP * 0.06, refund)
	_break_apart(tower, world)
	tower.queue_free()
	if _holder and _holder.has_method("pulse"):
		_holder.pulse(0.8, 0.12)


## The cell of a tower whose body is at `world_position`, or NO_CELL.
func _tower_cell_at(world_position: Vector3) -> Vector2i:
	var cell := board.world_to_cell(world_position)
	if board.tower_at(cell) == null:
		return NO_CELL
	var height := board.to_local(world_position).y - board.surface_height
	return cell if height > -0.01 and height < TOWER_HEIGHT else NO_CELL


func _go_home() -> void:
	_holder = null
	if _return_tween:
		_return_tween.kill()
	_return_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(self, "global_transform", _rest, RETURN_TIME)
	_return_tween.tween_callback(func() -> void: collision_layer = 10)


## The tower's model pieces fly off as loose chunks, then shrink away.
func _break_apart(tower: Tower, world: Node) -> void:
	var model := tower.get_node_or_null("Model")
	if model == null:
		return
	for piece: Node3D in model.get_children():
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		chunk.mass = 0.05
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * 0.03
		shape.shape = box
		chunk.add_child(shape)
		world.add_child(chunk)
		chunk.global_transform = Transform3D(Basis(), piece.global_position + Vector3.UP * 0.02)
		piece.reparent(chunk)
		chunk.linear_velocity = Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 0.9), randf_range(-0.4, 0.4))
		chunk.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		var tween := chunk.create_tween()
		tween.tween_interval(DEBRIS_LIFETIME)
		tween.tween_property(piece, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(chunk.queue_free)


## A "+52" that floats up and fades, so you see what you got back.
func _show_refund(world: Node, at: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "+%d" % amount
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.0005
	label.modulate = GOLD_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position", at + Vector3.UP * 0.08, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)
