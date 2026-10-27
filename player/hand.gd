extends Node3D
## One VR hand, parented to an XRController3D. Point the laser at a button
## and pull the trigger, or poke the button directly with the hand.
## Squeeze the grip to grab things (anything on the "grabbable" layer with a
## grab(hand) method) near the hand, or failing that, under the laser.
## grab() returns the object to call release() on when the grip lets go.
##
## Whatever the grip would grab is always highlighted (via hover_enter() /
## hover_exit()) before squeezing. While something is within reach the laser
## switches off, so a touch never grabs something further along the laser.

const GRABBABLE_LAYER := 8
## A new nearby object has to be this much closer than the current one to
## take over, so the highlight doesn't flicker between neighbours.
const SWITCH_MARGIN := 0.01

## Length of the laser when it isn't pointing at anything.
@export var idle_laser_length: float = 0.15
## How close to the hand something has to be to grab it directly.
@export var grab_radius: float = 0.07

@onready var _ray: InteractionRay = $InteractionRay
@onready var _laser: MeshInstance3D = $Laser
@onready var _controller := get_parent() as XRController3D

var _held: Object = null
## The nearby grabbable the grip would take, highlighted while not holding.
var _touching: Node3D = null


func _ready() -> void:
	if _controller:
		_controller.button_pressed.connect(_on_button_pressed)
		_controller.button_released.connect(_on_button_released)


func _physics_process(_delta: float) -> void:
	_set_touching(null if _held else _find_grabbable_nearby())
	# Touching something: no laser, so only that one thing is highlighted.
	_ray.enabled = _touching == null


func _process(_delta: float) -> void:
	var length := idle_laser_length
	if _ray.target:
		length = _ray.global_position.distance_to(_ray.get_collision_point())
	_laser.visible = _ray.enabled
	_laser.scale.z = length
	_laser.position.z = -length * 0.5


func _exit_tree() -> void:
	_set_touching(null)


func _on_button_pressed(action: String) -> void:
	match action:
		"trigger_click":
			if _touching and _touching.has_method("interact"):
				_touching.interact(_touching.global_position)
			else:
				_ray.interact()
		"grip_click":
			_grab()


func _on_button_released(action: String) -> void:
	if action == "grip_click":
		_release()


func _grab() -> void:
	if _held:
		return
	var target: Node = _touching
	if target == null and _ray.enabled and _ray.target and _ray.target.has_method("grab"):
		target = _ray.target
	if target:
		_set_touching(null)
		_held = target.grab(self)
		if _held:
			pulse(0.4, 0.08)


func _release() -> void:
	if is_instance_valid(_held):
		_held.release()
	_held = null


func _set_touching(body: Node3D) -> void:
	if body == _touching:
		return
	if is_instance_valid(_touching) and _touching.has_method("hover_exit"):
		_touching.hover_exit()
	_touching = body
	if _touching:
		if _touching.has_method("hover_enter"):
			_touching.hover_enter()
		pulse(0.15, 0.03)


## Buzzes the controller, e.g. when a held tool hits something.
func pulse(amplitude: float, duration: float) -> void:
	if _controller:
		_controller.trigger_haptic_pulse(&"haptic", 0.0, amplitude, duration, 0.0)


func _find_grabbable_nearby() -> Node3D:
	var sphere := SphereShape3D.new()
	sphere.radius = grab_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = GRABBABLE_LAYER
	var closest: Node3D = null
	var closest_distance := INF
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body := hit.collider as Node3D
		if body == null or not body.has_method("grab"):
			continue
		var distance := _distance_to(body)
		if body == _touching:
			distance -= SWITCH_MARGIN
		if distance < closest_distance:
			closest = body
			closest_distance = distance
	return closest


## Distance to the middle of a body's collision shape. Its origin can be far
## from that, e.g. a shop tower's origin is at its base.
func _distance_to(body: Node3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D:
			return (child as Node3D).global_position.distance_to(global_position)
	return body.global_position.distance_to(global_position)
