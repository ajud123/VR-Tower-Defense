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
## The face is the card's colour darkened by this much, so the white icons
## and text on it stay readable even on yellow cards.
const FACE_DARKEN := 0.45
## Just above the face, where the art is drawn. Stat icons sit on a badge
## over the target icon; the layers are spread out so they don't z-fight.
const ART_Z := 0.0026
const BADGE_Z := ART_Z + 0.0004
const STAT_Z := ART_Z + 0.0009
const BADGE_COLOR := Color(0.1, 0.1, 0.12)

var card: Card
var station: CardStation
var state: State = State.LOOSE

var _holder: Node3D
var _hold_offset: Transform3D
var _move_tween: Tween
var _face_material := StandardMaterial3D.new()
var _hover_count: int = 0


func _ready() -> void:
	collision_layer = PICKABLE_LAYERS
	collision_mask = WORLD_LAYER
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_face_material.albedo_color = card.color.darkened(FACE_DARKEN)
	_face_material.emission = card.color
	$Face.material_override = _face_material
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Card.RARITY_COLORS[card.rarity]
	if card.rarity != Card.Rarity.COMMON:
		frame.metallic = 0.7
		frame.roughness = 0.3
	if card.rarity == Card.Rarity.EPIC:
		frame.emission_enabled = true
		frame.emission = Card.RARITY_COLORS[card.rarity]
		frame.emission_energy_multiplier = 0.4
	$Frame.material_override = frame
	$Title.text = card.title
	$Back.text = "%s\n%s\n\n%s" % [card.title, Card.RARITY_NAMES[card.rarity], card.description]
	_draw_art()


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


# Lit up while a hand or pointer would pick it up.
func hover_enter() -> void:
	_hover_count += 1
	_face_material.emission_enabled = true


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_face_material.emission_enabled = _hover_count > 0


## The front: what the card affects and how, as icons. One effect gets a big
## picture (target, with the stat in a badge, and the amount below); several
## get a row each.
func _draw_art() -> void:
	var effects := card.effects()
	if effects.size() == 1:
		var effect: Dictionary = effects[0]
		_add_icon(effect.target, 0.036, Vector3(0, 0.003, ART_Z))
		_add_badge(Vector3(0.016, -0.011, BADGE_Z), 0.011)
		_add_icon(effect.stat, 0.016, Vector3(0.016, -0.011, STAT_Z), Icons.stat_color(effect.stat))
		_add_text(effect.text, 34, Vector2(0, -0.03))
		return
	for i in mini(effects.size(), 3):
		var effect: Dictionary = effects[i]
		var y := 0.012 - i * 0.022
		_add_icon(effect.target, 0.016, Vector3(-0.019, y, ART_Z))
		_add_icon(effect.stat, 0.016, Vector3(-0.002, y, ART_Z), Icons.stat_color(effect.stat))
		_add_text(effect.text, 20, Vector2(0.016, y))


func _add_icon(key: String, size: float, at: Vector3, color: Color = Color.WHITE) -> void:
	var icon := Icons.sprite(key, size, color)
	icon.position = at
	add_child(icon)


## A dark disc for a stat icon to sit on, so it stands out from the target.
func _add_badge(at: Vector3, radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.0002
	disc.radial_segments = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = BADGE_COLOR
	disc.material = material
	var badge := MeshInstance3D.new()
	badge.mesh = disc
	badge.rotation.x = PI / 2
	badge.position = at
	add_child(badge)


func _add_text(text: String, font_size: int, at: Vector2) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = font_size / 4
	label.pixel_size = 0.0004
	label.position = Vector3(at.x, at.y, ART_Z)
	add_child(label)


func _stop_moving() -> void:
	if _move_tween:
		_move_tween.kill()
