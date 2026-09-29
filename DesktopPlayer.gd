extends Node3D

@export var move_speed: float = 3.0
@export var fast_speed: float = 8.0
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D

var active: bool = false


func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)


func activate() -> void:
	active = true
	camera.make_current()
	set_process(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(
			camera.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)


func _process(delta: float) -> void:
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
