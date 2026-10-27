extends Node3D

@export var move_speed: float = 3.0
@export var fast_speed: float = 8.0
@export var mouse_sensitivity: float = 0.002
@export var crosshair_hover_color: Color = Color(1.0, 0.8, 0.2)

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: InteractionRay = $Camera3D/InteractionRay
@onready var hud: CanvasLayer = $HUD
@onready var crosshair: Label = $HUD/Crosshair
@onready var help: Label = $HUD/Help
## Things picked up (cards) are shown here, bottom right of the view.
@onready var hold_point: Node3D = $Camera3D/HoldPoint

var active: bool = false
## What's being held, or null. Anything with pick_up(holder) can be held;
## it's put down with accept_card() on a target or drop() into the world.
var held: Node3D = null


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)


func activate() -> void:
	active = true
	camera.make_current()
	hud.show()
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		help.visible = not help.visible
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_click()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and is_instance_valid(held):
		held.drop(camera.global_position - camera.global_basis.z * 0.4)
		held = null
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(
			camera.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)


func _click() -> void:
	var target := interaction_ray.target
	if is_instance_valid(held):
		# Tools (the hammer) are used where you click and stay in hand.
		if held.has_method("use_along"):
			var reach := interaction_ray.target_position.length()
			held.use_along(camera.global_position, camera.global_position - camera.global_basis.z * reach)
			return
		if not (target and target.has_method("accept_card") and target.accept_card(held)):
			held.drop(_drop_point())
		held = null
	elif target and target.has_method("pick_up") and target.pick_up(hold_point):
		held = target
	else:
		interaction_ray.interact()


## Where the crosshair meets the world, a little above it so things fall onto it.
func _drop_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_basis.z * interaction_ray.target_position.length()
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 0b11)
	)
	if hit:
		return hit.position + hit.normal * 0.05
	return from - camera.global_basis.z * 0.6


func _process(delta: float) -> void:
	# Only aim at things while the crosshair is actually in use.
	interaction_ray.enabled = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	crosshair.modulate = crosshair_hover_color if interaction_ray.target else Color.WHITE

	# Releasing the cursor also pauses movement so editor input is safe.
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not get_window().has_focus():
		return

	var movement := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var speed := fast_speed if Input.is_physical_key_pressed(KEY_SHIFT) else move_speed
	# Yaw determines horizontal movement; looking up/down does not change altitude.
	position += basis * movement.normalized() * speed * delta
