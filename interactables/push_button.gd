@tool
extends StaticBody3D
## Chunky arcade-style button. Poke it with a VR hand, point at it and pull
## the trigger, or aim at it and left click in desktop mode.

signal pressed

const LABEL_PIXEL_SIZE := 0.002

@export var text: String = "BUTTON":
	set(value):
		text = value
		if is_node_ready():
			$Label3D.text = value
@export var color: Color = Color(0.85, 0.16, 0.12):
	set(value):
		color = value
		if is_node_ready() and not Engine.is_editor_hint():
			_update_cap()
## Size of the text above the button, relative to the default.
@export var label_scale: float = 1.0:
	set(value):
		label_scale = value
		if is_node_ready():
			$Label3D.pixel_size = LABEL_PIXEL_SIZE * value
## Seconds before the button can be pressed again.
@export var cooldown: float = 0.5

@onready var _cap: MeshInstance3D = $Cap

var _cap_material := StandardMaterial3D.new()
var _cap_rest_y: float
var _hover_count: int = 0
var _next_press_msec: int = 0


func _ready() -> void:
	$Label3D.text = text
	$Label3D.pixel_size = LABEL_PIXEL_SIZE * label_scale
	if Engine.is_editor_hint():
		return
	_cap_rest_y = _cap.position.y
	_cap.material_override = _cap_material
	_update_cap()
	$PokeZone.area_entered.connect(func(_hand: Area3D) -> void: interact())


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_press_msec:
		return
	_next_press_msec = now + int(cooldown * 1000.0)
	# Emit once the cap bottoms out so the press is visible before anything
	# reacts (e.g. a scene change).
	var tween := create_tween()
	tween.tween_property(_cap, "position:y", _cap_rest_y - 0.02, 0.06)
	tween.tween_callback(pressed.emit)
	tween.tween_property(_cap, "position:y", _cap_rest_y, 0.15)


func hover_enter() -> void:
	_hover_count += 1
	_update_cap()


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_update_cap()


func _update_cap() -> void:
	var hovered := _hover_count > 0
	_cap_material.albedo_color = color.lightened(0.25) if hovered else color
	_cap_material.emission_enabled = hovered
	_cap_material.emission = color
	_cap_material.emission_energy_multiplier = 0.8
