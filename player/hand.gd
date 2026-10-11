extends Node3D
## One VR hand, parented to an XRController3D. Point the laser at a button
## and pull the trigger, or poke the button directly with the hand.
## Squeeze the grip to grab things (anything on the "grabbable" layer with a
## grab(hand) method) near the hand, or failing that, under the laser.
## grab() returns the object to call release() on when the grip lets go.

const GRABBABLE_LAYER := 8

## Length of the laser when it isn't pointing at anything.
@export var idle_laser_length: float = 0.15
## How close to the hand something has to be to grab it directly.
@export var grab_radius: float = 0.07

@onready var _ray: InteractionRay = $InteractionRay
@onready var _laser: MeshInstance3D = $Laser
@onready var _controller := get_parent() as XRController3D

var _held: Object = null


func _ready() -> void:
	if _controller:
		_controller.button_pressed.connect(_on_button_pressed)
		_controller.button_released.connect(_on_button_released)


func _process(_delta: float) -> void:
	var length := idle_laser_length
	if _ray.target:
		length = _ray.global_position.distance_to(_ray.get_collision_point())
	_laser.scale.z = length
	_laser.position.z = -length * 0.5


func _on_button_pressed(action: String) -> void:
	match action:
		"trigger_click":
			_ray.interact()
		"grip_click":
			_grab()


func _on_button_released(action: String) -> void:
	if action == "grip_click":
		_release()


func _grab() -> void:
	if _held:
		return
	var target := _find_grabbable_nearby()
	if target == null and _ray.target and _ray.target.has_method("grab"):
		target = _ray.target
	if target:
		_held = target.grab(self)
		if _held:
			_controller.trigger_haptic_pulse(&"haptic", 0.0, 0.4, 0.08, 0.0)


func _release() -> void:
	if is_instance_valid(_held):
		_held.release()
	_held = null


func _find_grabbable_nearby() -> Node:
	var sphere := SphereShape3D.new()
	sphere.radius = grab_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = GRABBABLE_LAYER
	var closest: Node3D = null
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body := hit.collider as Node3D
		if body and body.has_method("grab") and (closest == null
				or body.global_position.distance_to(global_position)
				< closest.global_position.distance_to(global_position)):
			closest = body
	return closest
