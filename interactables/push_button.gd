@tool
class_name PushButton
extends StaticBody3D
## Chunky arcade-style button. Poke it with a VR hand, point at it and pull
## the trigger, or aim at it and left click in desktop mode.
## With an icon it's printed on the cap; otherwise the text floats above it.

signal pressed

const LABEL_PIXEL_SIZE := 0.002
## How wide the icon is on the cap, in metres.
const ICON_SIZE := 0.1
const PRESS_DEPTH := 0.022

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
## Printed on top of the cap instead of the floating text. White on clear,
## e.g. one of gameplay/icons/.
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_update_icon()
## Size of the text above the button, relative to the default.
@export var label_scale: float = 1.0:
	set(value):
		label_scale = value
		if is_node_ready():
			$Label3D.pixel_size = LABEL_PIXEL_SIZE * value
## Seconds before the button can be pressed again.
@export var cooldown: float = 0.5
## When true, the cap stays depressed once pressed until unpress() is called.
@export var stay_pressed: bool = false
## Gently pulses the cap glow while unpressed and idle.
@export var pulse_when_unpressed: bool = false
## Keeps the floating label visible even with an icon until the button is pressed.
@export var show_label_until_pressed: bool = false:
	set(value):
		show_label_until_pressed = value
		if is_node_ready():
			_update_label()

@onready var _cap: MeshInstance3D = $Cap

var is_pressed: bool = false

var _cap_material := StandardMaterial3D.new()
var _cap_rest_y: float
var _hover_count: int = 0
var _next_press_msec: int = 0
var _press_tween: Tween
var _pulse_time: float = 0.0


func _ready() -> void:
	$Label3D.text = text
	$Label3D.pixel_size = LABEL_PIXEL_SIZE * label_scale
	_update_icon()
	if Engine.is_editor_hint():
		return
	_cap_rest_y = _cap.position.y
	_cap.material_override = _cap_material
	_update_cap()
	$PokeZone.area_entered.connect(func(_hand: Area3D) -> void: interact())


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if pulse_when_unpressed and not is_pressed and _hover_count == 0:
		_pulse_time += delta
		_cap_material.emission_enabled = true
		_cap_material.emission = color
		_cap_material.emission_energy_multiplier = 0.15 + 0.4 * (0.5 + 0.5 * sin(_pulse_time * 3.2))


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	if stay_pressed and is_pressed:
		return
	var now := Time.get_ticks_msec()
	if now < _next_press_msec:
		return
	_next_press_msec = now + int(cooldown * 1000.0)
	if not Engine.is_editor_hint():
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_3d("button_press", global_position)
	# Emit once the cap bottoms out so the press is visible before anything
	# reacts (e.g. a scene change).
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	if stay_pressed:
		is_pressed = true
		_update_cap()
		_update_label()
		_press_tween.tween_property(_cap, "position:y", _cap_rest_y - PRESS_DEPTH, 0.06)
		_press_tween.tween_callback(pressed.emit)
	else:
		_press_tween.tween_property(_cap, "position:y", _cap_rest_y - PRESS_DEPTH, 0.06)
		_press_tween.tween_callback(pressed.emit)
		_press_tween.tween_property(_cap, "position:y", _cap_rest_y, 0.15)


## Pops a latching button back out. Returns the tween when animating, or null.
func unpress(instant: bool = false) -> Tween:
	if not is_pressed:
		return null
	is_pressed = false
	_next_press_msec = 0
	_pulse_time = 0.0
	if _press_tween:
		_press_tween.kill()
		_press_tween = null
	_update_cap()
	_update_label()
	if instant:
		_cap.position.y = _cap_rest_y
		return null
	_press_tween = create_tween()
	_press_tween.tween_property(_cap, "position:y", _cap_rest_y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _press_tween


func hover_enter() -> void:
	_hover_count += 1
	_update_cap()


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_update_cap()


func _update_cap() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if is_pressed:
		_cap_material.albedo_color = color.darkened(0.38)
		_cap_material.emission_enabled = false
		return
	var hovered := _hover_count > 0
	_cap_material.albedo_color = color.lightened(0.25) if hovered else color
	_cap_material.emission_enabled = hovered or pulse_when_unpressed
	_cap_material.emission = color
	_cap_material.emission_energy_multiplier = 0.8 if hovered else 0.35


func _update_icon() -> void:
	var sprite := $Cap/Icon as Sprite3D
	sprite.texture = icon
	sprite.visible = icon != null
	if icon:
		sprite.pixel_size = ICON_SIZE / icon.get_width()
	_update_label()


func _update_label() -> void:
	$Label3D.visible = (icon == null) or (show_label_until_pressed and not is_pressed)
