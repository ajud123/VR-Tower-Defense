class_name CardView
extends RigidBody3D
## A card the player owns, as a physical object. It can lie loose in the
## world (falling and landing like a real card), be held, sit in the card
## station's storage, or be active in one of its slots.
##
## VR: grab it with the grip (touching it or with the laser) and let go over a
## slot, over the storage mat, or anywhere else to drop it.
## Desktop: click it to pick it up (it shows bottom right), then click a slot,
## the storage mat or anywhere else to put it down.

enum State { LOOSE, HELD, STORED, ACTIVE }

const MOVE_TIME := 0.35
## Interactable + grabbable, so rays and hands find it.
const PICKABLE_LAYERS := 10
const WORLD_LAYER := 1
## Where the card sits relative to a VR hand holding it.
const HAND_OFFSET := Transform3D(Basis(), Vector3(0, -0.05, -0.02))

var card: Card
var station: CardStation
var state: State = State.LOOSE

var _holder: Node3D
var _hold_offset: Transform3D
var _move_tween: Tween


func _ready() -> void:
	collision_layer = PICKABLE_LAYERS
	collision_mask = WORLD_LAYER
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var face := StandardMaterial3D.new()
	face.albedo_color = card.color
	$Face.material_override = face
	$Title.text = card.title
	$Description.text = card.description


func _process(_delta: float) -> void:
	if state != State.HELD:
		return
	if is_instance_valid(_holder):
		global_transform = _holder.global_transform * _hold_offset
	else:
		drop(global_position)


## Picks the card up, taking it out of the station if it was there. It then
## follows `holder`, posed by `offset` relative to it.
func pick_up(holder: Node3D, offset: Transform3D = Transform3D.IDENTITY) -> bool:
	if state == State.HELD:
		return false
	station.take(self)
	_stop_moving()
	state = State.HELD
	_holder = holder
	_hold_offset = offset
	freeze = true
	collision_layer = 0
	return true


## Lets the card fall from `world_position`.
func drop(world_position: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	_stop_moving()
	_holder = null
	state = State.LOOSE
	global_position = world_position
	collision_layer = PICKABLE_LAYERS
	freeze = false
	linear_velocity = velocity
	# A little tumble, or a card let go upright lands balanced on its edge.
	angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-2.0, 2.0), randf_range(-4.0, 4.0))


## Called by the station: glide into storage or a slot and stay there.
func settle(new_state: State, target: Transform3D) -> void:
	_holder = null
	state = new_state
	collision_layer = PICKABLE_LAYERS
	freeze = true
	if global_transform.is_equal_approx(target):
		return
	_stop_moving()
	_move_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_transform", target, MOVE_TIME)


# VR grip.
func grab(hand: Node3D) -> Object:
	return self if pick_up(hand, HAND_OFFSET) else null


# VR grip let go: into a slot or storage if it's over one, else it drops.
func release() -> void:
	if state == State.HELD:
		station.put_down(self)


# Desktop: a held card clicked onto this one swaps places with it.
func accept_card(other: CardView) -> bool:
	match state:
		State.ACTIVE:
			return station.place(other, station.slot_of(self))
		State.STORED:
			return station.place(other, CardStation.STORAGE)
	return false


# Cards are picked up, not pressed; this just makes rays target them.
func interact(_point: Vector3 = Vector3.ZERO) -> void:
	pass


func _stop_moving() -> void:
	if _move_tween:
		_move_tween.kill()
