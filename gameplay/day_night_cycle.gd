class_name DayNightCycle
extends Node3D
## Cozy, slow day-night cycle for the park.
## Smoothly transitions sky colors, sun arc, soft moonlight, starry night dome,
## park lantern glow, and ambient bird activity.
##
## `time_of_day` runs 0.0 .. 1.0:
##   0.00 = midnight
##   0.22 = dawn / sunrise
##   0.32 = bright late morning (default start)
##   0.50 = midday
##   0.74 = golden sunset
##   0.83 = cozy dusk / twilight
##   0.92 = starry night

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var park_ambience: Node
## Length of daytime (sunrise to sunset) in seconds (180s = 3 minutes).
@export var day_duration: float = 180.0
## Length of nighttime (sunset through starry night to dawn) in seconds (60s = 1 minute).
@export var night_duration: float = 60.0
## Starting time of day (0.32 = cheerful sunny morning).
@export_range(0.0, 1.0) var start_time: float = 0.32
## Picks a random starting time of day each playthrough when enabled.
@export var randomize_start_time: bool = true
@export var paused: bool = false

## Current normalized time of day (0..1).
var time_of_day: float = 0.32
## True while the sun is high enough to focus sunlight with the Magnifier.
var is_daylight: bool = true

var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _stars: Node3D
var _star_mat: StandardMaterial3D
var _sky_update_accum: float = 0.0

## How often (seconds) to push sky/fog color updates so Forward Mobile isn't
## rebuilding sky radiance cubemaps every frame.
const SKY_UPDATE_INTERVAL := 0.25

# Color keyframes sorted by time (0..1).
const SKY_TOP := [
	[0.00, Color(0.03, 0.05, 0.13)],
	[0.20, Color(0.08, 0.11, 0.26)],
	[0.26, Color(0.24, 0.42, 0.72)],
	[0.36, Color(0.30, 0.52, 0.85)],
	[0.64, Color(0.29, 0.50, 0.83)],
	[0.74, Color(0.25, 0.31, 0.56)],
	[0.82, Color(0.07, 0.09, 0.22)],
	[0.92, Color(0.03, 0.05, 0.13)],
	[1.00, Color(0.03, 0.05, 0.13)],
]
const SKY_HORIZON := [
	[0.00, Color(0.07, 0.10, 0.20)],
	[0.19, Color(0.26, 0.20, 0.32)],
	[0.24, Color(0.95, 0.62, 0.42)],
	[0.32, Color(0.74, 0.82, 0.91)],
	[0.64, Color(0.75, 0.81, 0.89)],
	[0.74, Color(0.96, 0.54, 0.32)],
	[0.81, Color(0.24, 0.18, 0.34)],
	[0.90, Color(0.07, 0.10, 0.20)],
	[1.00, Color(0.07, 0.10, 0.20)],
]
const GROUND_BOTTOM := [
	[0.00, Color(0.04, 0.06, 0.07)],
	[0.24, Color(0.16, 0.18, 0.14)],
	[0.35, Color(0.22, 0.30, 0.18)],
	[0.68, Color(0.22, 0.28, 0.17)],
	[0.82, Color(0.07, 0.09, 0.10)],
	[1.00, Color(0.04, 0.06, 0.07)],
]
const SUN_COLOR := [
	[0.00, Color(0.45, 0.58, 0.88)],  # soft cool moonlight
	[0.21, Color(0.95, 0.55, 0.35)],  # sunrise
	[0.30, Color(1.00, 0.96, 0.88)],  # warm morning
	[0.50, Color(1.00, 0.98, 0.94)],  # bright midday
	[0.68, Color(1.00, 0.90, 0.72)],  # late afternoon
	[0.75, Color(0.98, 0.54, 0.30)],  # golden sunset
	[0.82, Color(0.45, 0.58, 0.88)],  # moonlit dusk
	[1.00, Color(0.45, 0.58, 0.88)],
]
const CLOUD_COLOR := [
	[0.00, Color(0.18, 0.23, 0.38)],  # moonlit night indigo
	[0.20, Color(0.55, 0.42, 0.56)],  # pre-dawn lavender
	[0.24, Color(1.00, 0.78, 0.66)],  # cotton-candy sunrise
	[0.32, Color(0.99, 0.98, 0.96)],  # fluffy cream morning
	[0.65, Color(0.99, 0.98, 0.95)],  # warm afternoon
	[0.74, Color(1.00, 0.72, 0.58)],  # dreamy peach-pink sunset
	[0.81, Color(0.38, 0.30, 0.48)],  # twilight violet
	[0.90, Color(0.18, 0.23, 0.38)],  # starry night
	[1.00, Color(0.18, 0.23, 0.38)],
]


func _ready() -> void:
	add_to_group("day_night")
	time_of_day = randf() if randomize_start_time else start_time
	if world_environment and world_environment.environment:
		# Duplicate so runtime color changes never dirty the saved scene resource.
		_env = world_environment.environment.duplicate() as Environment
		if _env.sky and _env.sky.sky_material is ProceduralSkyMaterial:
			var sky_copy := _env.sky.duplicate() as Sky
			_sky_mat = sky_copy.sky_material.duplicate() as ProceduralSkyMaterial
			sky_copy.sky_material = _sky_mat
			_env.sky = sky_copy
		world_environment.environment = _env
	_build_stars()
	_apply_time(time_of_day, true)
	# Sync Park siblings (LampPost, ParkClouds, ParkAmbience) once the tree is ready.
	_apply_time.call_deferred(time_of_day, true)


func _process(delta: float) -> void:
	if not paused:
		var is_day_half := time_of_day >= 0.25 and time_of_day < 0.75
		var half_len := maxf(day_duration if is_day_half else night_duration, 1.0)
		time_of_day = fposmod(time_of_day + delta * (0.5 / half_len), 1.0)
	_sky_update_accum += delta
	var update_sky := _sky_update_accum >= SKY_UPDATE_INTERVAL
	if update_sky:
		_sky_update_accum = fmod(_sky_update_accum, SKY_UPDATE_INTERVAL)
	_apply_time(time_of_day, update_sky)


func _apply_time(t: float, update_sky: bool) -> void:
	# Sun elevation: -1 at midnight (0.0), 0 at 0.25 & 0.75, +1 at noon (0.5).
	var sun_phase := (t - 0.25) * TAU
	var elev := sin(sun_phase)
	is_daylight = elev > 0.08

	# Night factor: 0 in full day, 1 in full night.
	var night := clampf(inverse_lerp(0.22, -0.18, elev), 0.0, 1.0)

	# Throttled sky, ambient & fog updates (~4 Hz) avoid constant radiance rebakes on mobile VR.
	if update_sky:
		var top := _sample_color(SKY_TOP, t)
		var horizon := _sample_color(SKY_HORIZON, t)
		var ground := _sample_color(GROUND_BOTTOM, t)
		if _sky_mat:
			_sky_mat.sky_top_color = top
			_sky_mat.sky_horizon_color = horizon
			_sky_mat.ground_horizon_color = horizon
			_sky_mat.ground_bottom_color = ground
		if _env:
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color(0.75, 0.82, 0.90).lerp(Color(0.18, 0.24, 0.42), night)
			_env.ambient_light_energy = lerpf(0.35, 0.42, night)
			_env.fog_enabled = true
			_env.fog_mode = Environment.FOG_MODE_DEPTH
			_env.fog_depth_begin = 18.0
			_env.fog_depth_end = 38.5
			_env.fog_depth_curve = 1.4
			_env.fog_light_color = horizon
			_env.fog_light_energy = 1.0
			_env.fog_sky_affect = 0.0
		var cloud_tint := _sample_color(CLOUD_COLOR, t)
		var cloud_glow := lerpf(0.32, 0.14, night)
		for clouds in get_tree().get_nodes_in_group("park_clouds"):
			if clouds.has_method("set_tint"):
				clouds.set_tint(cloud_tint, cloud_tint, cloud_glow)
		if park_ambience and park_ambience.has_method("set_night_factor"):
			park_ambience.set_night_factor(night)

	# Sun / Moon directional light arc.
	if sun:
		sun.light_color = _sample_color(SUN_COLOR, t)
		if elev >= -0.02:
			# Sun travels smoothly east-to-west across the sky dome.
			var pitch := -lerpf(6.0, 62.0, clampf(elev, 0.0, 1.0))
			var yaw := lerpf(65.0, -65.0, clampf((t - 0.22) / 0.56, 0.0, 1.0))
			sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
			sun.light_energy = lerpf(0.18, 1.15, smoothstep(-0.02, 0.28, elev))
		else:
			# Soft moonlight from high angle at night so the park stays readable & cozy.
			sun.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
			sun.light_energy = lerpf(0.15, 0.26, smoothstep(-0.02, -0.25, elev))

	# Lanterns start warming up during golden hour and shine fully at twilight/night.
	var lamp_glow := smoothstep(0.28, -0.08, elev)
	for lamp in get_tree().get_nodes_in_group("park_lamps"):
		if lamp.has_method("set_glow"):
			lamp.set_glow(lamp_glow)

	# Stars fade in smoothly at dusk and rotate gently across the sky.
	if _stars and _star_mat:
		var star_alpha := smoothstep(0.35, 0.85, night)
		_stars.visible = star_alpha > 0.01
		_star_mat.albedo_color = Color(1.0, 0.97, 0.9, star_alpha * 0.85)
		_stars.rotation.y = t * TAU * 0.25


func _build_stars() -> void:
	_stars = Node3D.new()
	_stars.name = "Stars"
	add_child(_stars)

	var rng := RandomNumberGenerator.new()
	rng.seed = 202611
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.disable_fog = true
	_star_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.0)

	var dot := SphereMesh.new()
	dot.radius = 0.14
	dot.height = 0.28
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _star_mat

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dot
	var count := 90
	multi.instance_count = count
	for i in count:
		var theta := rng.randf() * TAU
		var phi := rng.randf_range(0.2, 1.38)
		var r := 44.0
		var pos := Vector3(cos(theta) * cos(phi) * r, sin(phi) * r, sin(theta) * cos(phi) * r)
		var sc := rng.randf_range(0.6, 1.5)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sc), pos))

	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multi
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.add_child(inst)
	_stars.visible = false


func _sample_color(keys: Array, t: float) -> Color:
	for i in range(keys.size() - 1):
		var t0: float = keys[i][0]
		var t1: float = keys[i + 1][0]
		if t >= t0 and t <= t1:
			var f := (t - t0) / maxf(t1 - t0, 0.0001)
			return (keys[i][1] as Color).lerp(keys[i + 1][1] as Color, f)
	return keys[0][1]
