@tool
class_name LampPost
extends Node3D
## Tall park streetlamp using the Kenney graveyard lightpost, painted metal
## grey with a warm glowing inner lantern core, soft radial halo sprite, and
## OmniLight3D driven by the day-night cycle.

const LAMP_MODEL := preload("res://assets/kenney/graveyard/lightpost-single.glb")
const LAMP_COLORMAP := preload("res://assets/kenney/graveyard/Textures/colormap_lamp.png")
## Exact centre of the hanging lantern cage in lightpost-single.glb local space.
const LANTERN_CENTER := Vector3(0.0, 1.025, 0.263)
const WARM_BULB_COLOR := Color(1.0, 0.86, 0.48)
const WARM_LIGHT_COLOR := Color(1.0, 0.78, 0.42)
const OFF_GLASS_COLOR := Color(0.82, 0.76, 0.52)

## Overall scale of the lamp post (1.0 is ~1.27 m; 2.5 is ~3.17 m tall).
@export var post_scale: float = 2.5:
	set(value):
		post_scale = maxf(value, 0.5)
		if is_node_ready():
			_apply_scale()
## Peak light energy at full night.
@export var max_light_energy: float = 2.4
## Reach of the lantern's warm light in metres.
@export var light_range: float = 8.5:
	set(value):
		light_range = maxf(value, 1.0)
		if _light:
			_light.omni_range = light_range
## Editor preview glow (0 = day, 1 = night); driven live by DayNightCycle at runtime.
@export_range(0.0, 1.0) var preview_glow: float = 0.0:
	set(value):
		preview_glow = clampf(value, 0.0, 1.0)
		if is_node_ready():
			set_glow(preview_glow)

static var _halo_texture: ImageTexture

var _model: Node3D
var _bulb_mesh: MeshInstance3D
var _bulb_mat: StandardMaterial3D
var _halo_sprite: Sprite3D
var _light: OmniLight3D
var _glow: float = 0.0
var _flicker_seed: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("park_lamps")
	_flicker_seed = fmod(absf(global_position.x * 3.7 + global_position.z * 5.3), TAU)
	_build_lamp()
	_apply_scale()
	set_glow(preview_glow if Engine.is_editor_hint() else 0.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _glow <= 0.01 or _light == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var flicker := 1.0 + sin(t * 4.3 + _flicker_seed) * 0.03 + sin(t * 9.7 + _flicker_seed * 2.1) * 0.02
	_light.light_energy = max_light_energy * _glow * flicker
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = lerpf(0.0, 4.2, _glow) * flicker


## Sets how strongly the lantern is lit (0 = off in bright daylight, 1 = full night).
func set_glow(strength: float) -> void:
	_glow = clampf(strength, 0.0, 1.0)
	if _bulb_mat:
		_bulb_mat.albedo_color = OFF_GLASS_COLOR.lerp(WARM_BULB_COLOR, _glow)
		_bulb_mat.emission_enabled = _glow > 0.02
		_bulb_mat.emission = WARM_BULB_COLOR
		_bulb_mat.emission_energy_multiplier = lerpf(0.0, 4.2, _glow)
	if _halo_sprite:
		_halo_sprite.visible = _glow > 0.05
		_halo_sprite.modulate = Color(WARM_BULB_COLOR.r, WARM_BULB_COLOR.g, WARM_BULB_COLOR.b, _glow * 0.55)
	if _light:
		_light.visible = _glow > 0.01
		_light.light_energy = max_light_energy * _glow


func _build_lamp() -> void:
	for child in get_children():
		child.queue_free()

	_model = LAMP_MODEL.instantiate()
	_model.name = "Model"
	add_child(_model)

	var metal := StandardMaterial3D.new()
	metal.albedo_texture = LAMP_COLORMAP
	metal.metallic = 0.6
	metal.roughness = 0.45
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = metal

	# Inner glowing lantern glass tucked neatly inside the metal cage bars (no clipping).
	var core := CylinderMesh.new()
	core.top_radius = 0.056
	core.bottom_radius = 0.052
	core.height = 0.11
	core.radial_segments = 8
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = OFF_GLASS_COLOR
	_bulb_mat.roughness = 0.25
	core.material = _bulb_mat
	_bulb_mesh = MeshInstance3D.new()
	_bulb_mesh.mesh = core
	_bulb_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bulb_mesh)

	# Smooth radial-gradient glow sprite (no hard sphere edges).
	_halo_sprite = Sprite3D.new()
	_halo_sprite.texture = _get_halo_texture()
	_halo_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_sprite.shaded = false
	_halo_sprite.transparent = true
	_halo_sprite.no_depth_test = false
	_halo_sprite.pixel_size = 0.008
	_halo_sprite.modulate = Color(WARM_BULB_COLOR, 0.0)
	_halo_sprite.visible = false
	var sprite_mat := StandardMaterial3D.new()
	sprite_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sprite_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_mat.albedo_texture = _get_halo_texture()
	sprite_mat.vertex_color_use_as_albedo = true
	sprite_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_halo_sprite.material_override = sprite_mat
	add_child(_halo_sprite)

	# Warm OmniLight3D (no shadows for crisp mobile VR performance).
	_light = OmniLight3D.new()
	_light.light_color = WARM_LIGHT_COLOR
	_light.omni_range = light_range
	_light.omni_attenuation = 1.35
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)


func _apply_scale() -> void:
	if _model:
		_model.scale = Vector3.ONE * post_scale
	var lantern_pos := LANTERN_CENTER * post_scale
	if _bulb_mesh:
		_bulb_mesh.position = lantern_pos
		_bulb_mesh.scale = Vector3.ONE * post_scale
	if _halo_sprite:
		_halo_sprite.position = lantern_pos
		_halo_sprite.pixel_size = 0.0065 * post_scale
	if _light:
		# Offset slightly below the lantern roof so the light illuminates ground & table cleanly.
		_light.position = lantern_pos + Vector3(0, -0.1 * post_scale, 0)


static func _get_halo_texture() -> ImageTexture:
	if _halo_texture:
		return _halo_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (x - half) / half
			var dy := (y - half) / half
			var d := sqrt(dx * dx + dy * dy)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.6)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_halo_texture = ImageTexture.create_from_image(img)
	return _halo_texture
