class_name Recycler
extends StaticBody3D
## The card recycler: drop or click unwanted cards into the shredder to get your gold back.
##
## How it works:
## - On Desktop: click a card to pick it up, then click the Recycler to feed it in.
## - In VR: grab a card and drop it directly into the top hopper chute.
## - The twin shredder drums spin up, chewing through the card with grinding sparks
##   and paper shreds.
## - Pays out the gold you spent on the card (100% refund by default) with a floating text banner.
## - Steps the vending machine's price back down so you can pull again at the same price.
## - Returns the card to the unowned card pool, updating the vending machine display.

const IDLE_SPEED := 1.5
const SHRED_SPEED := 24.0
const GOLD_COLOR := Color(1.0, 0.85, 0.25)

@export var game: GameState
@export var station: CardStation
@export var vending_machine: Node3D
## Fraction of the card's purchase price refunded (1.0 = 100% full refund).
@export var refund_ratio: float = 1.0

@onready var _model: Node3D = $Model
@onready var _cyl1: Node3D = $Model/Cylinder
@onready var _cyl2: Node3D = $Model/Cylinder_001
@onready var _screen: Label3D = $Screen
@onready var _hopper: Area3D = $Hopper
@onready var _sparks: CPUParticles3D = $Sparks
@onready var _shreds: CPUParticles3D = $Shreds

var _speed: float = IDLE_SPEED
var _target_speed: float = IDLE_SPEED
var _shredding_cards: Dictionary = {}
var _shredding_count: int = 0
var _hover_count: int = 0


func _ready() -> void:
	add_to_group("recycler")
	collision_layer = 10
	collision_mask = 0
	if _hopper:
		_hopper.body_entered.connect(_on_hopper_body_entered)
	_find_dependencies()
	_update_screen_idle()


func _process(delta: float) -> void:
	_target_speed = SHRED_SPEED if _shredding_count > 0 else IDLE_SPEED
	_speed = move_toward(_speed, _target_speed, delta * 35.0)
	if _cyl1 and _cyl2:
		_cyl1.rotate_x(delta * _speed)
		_cyl2.rotate_x(-delta * _speed)


func _find_dependencies() -> void:
	if game == null:
		game = get_node_or_null("../Game") as GameState
	if station == null:
		station = get_node_or_null("../PicnicTable/CardStation") as CardStation
	if vending_machine == null:
		vending_machine = get_node_or_null("../VendingMachine")


## Desktop: called when the player clicks on the Recycler with a held card.
func accept_card(view: CardView) -> bool:
	if view == null or not is_instance_valid(view) or _shredding_cards.has(view):
		return false
	_shred_card(view)
	return true


## Checks if a world position is within the hopper opening above the shredder.
func is_point_in_hopper(world_point: Vector3) -> bool:
	var local := to_local(world_point)
	return absf(local.x) < 0.55 and local.y > 0.15 and local.y < 0.85 and absf(local.z - (-0.02)) < 0.45


## Called when a physical card falls into the hopper.
func _on_hopper_body_entered(body: Node) -> void:
	var view := body as CardView
	if view and not _shredding_cards.has(view) and view.state != CardView.State.HELD:
		accept_card(view)


func _shred_card(view: CardView) -> void:
	_shredding_cards[view] = true
	_shredding_count += 1

	if view.state == CardView.State.HELD:
		view._holder = null
		view.state = CardView.State.LOOSE

	view._stop_moving()
	view.freeze = true
	view.collision_layer = 0
	view.linear_velocity = Vector3.ZERO
	view.angular_velocity = Vector3.ZERO

	var refund := get_refund_for(view)

	_screen.text = "SHREDDING...\n+%d GOLD" % refund
	_screen.modulate = Color(1.0, 0.85, 0.3)

	var hopper_top := to_global(Vector3(0, 0.45, -0.02))
	var shred_depth := to_global(Vector3(0, 0.05, -0.02))

	var tween := create_tween()
	# Align upright at mouth of hopper
	tween.tween_property(view, "global_position", hopper_top, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(view, "quaternion", global_basis.get_rotation_quaternion(), 0.18)

	# Pull down between the grinding cylinders while squashing
	tween.tween_property(view, "global_position", shred_depth, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(view, "scale", Vector3(0.05, 0.02, 0.05), 0.42)

	# Emit sparks and card shreds mid-way
	tween.parallel().tween_callback(func():
		_start_shred_particles(view.card.color)
	).set_delay(0.12)

	# Payout and cleanup
	tween.chain().tween_callback(func():
		_finish_shred(view, refund)
	)


func _finish_shred(view: CardView, refund: int) -> void:
	_stop_shred_particles()
	_shredding_cards.erase(view)
	_shredding_count = maxi(_shredding_count - 1, 0)

	var world := get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	var at := to_global(Vector3(0, 0.45, -0.02))

	if world and is_inside_tree():
		Effects.burst(world, at, GOLD_COLOR, 20, 0.009, 0.18, 0.6)
		Effects.burst(world, at + Vector3.UP * 0.04, Color(1.0, 1.0, 0.7), 12, 0.006, 0.12, 0.4)
		_show_refund(world, at + Vector3.UP * 0.08, refund)

	if game:
		game.earn(refund)

	if vending_machine and vending_machine.has_method("refund_card"):
		vending_machine.refund_card(view)

	if station and is_instance_valid(view):
		station.destroy_card(view)
	elif is_instance_valid(view):
		view.queue_free()

	_screen.text = "RECYCLED!\n+%d GOLD" % refund
	_screen.modulate = Color(0.3, 1.0, 0.4)

	if is_inside_tree():
		get_tree().create_timer(2.0).timeout.connect(func():
			if _shredding_count == 0:
				_update_screen_idle()
		)


func get_refund_for(view: CardView) -> int:
	if view.paid > 0:
		return roundi(view.paid * refund_ratio)
	match view.card.rarity:
		Card.Rarity.COMMON:
			return 100
		Card.Rarity.RARE:
			return 250
		Card.Rarity.EPIC:
			return 400
		_:
			return 100


func _start_shred_particles(card_color: Color) -> void:
	if _sparks:
		_sparks.emitting = true
	if _shreds:
		_shreds.color = card_color
		_shreds.emitting = true


func _stop_shred_particles() -> void:
	if _sparks:
		_sparks.emitting = false
	if _shreds:
		_shreds.emitting = false


func _show_refund(world: Node, at: Vector3, amount: int) -> void:
	if not world or not is_inside_tree():
		return
	var label := Label3D.new()
	label.text = "+%d GOLD" % amount
	label.font_size = 42
	label.outline_size = 10
	label.pixel_size = 0.0006
	label.modulate = GOLD_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", at.y + 0.16, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	if _shredding_count == 0:
		_screen.text = "CARD RECYCLER\nDrop card here\nto get refund!"
		_screen.modulate = Color(1.0, 0.9, 0.4)
		if is_inside_tree():
			get_tree().create_timer(2.0).timeout.connect(_update_screen_idle)


func hover_enter() -> void:
	_hover_count += 1
	_update_screen_hover()


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_update_screen_hover()


func _update_screen_hover() -> void:
	if _shredding_count > 0:
		return
	if _hover_count > 0:
		_screen.text = "RECYCLER\nDrop to scrap"
		_screen.modulate = Color(1.0, 0.9, 0.4)
	else:
		_update_screen_idle()


func _update_screen_idle() -> void:
	if _shredding_count > 0:
		return
	_screen.text = "RECYCLER\nScrap cards\nfor refund"
	_screen.modulate = Color(0.3, 0.9, 0.45)
