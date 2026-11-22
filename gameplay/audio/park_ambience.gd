extends Node3D
## Cozy park soundscape: gentle wind + distant park birdsong beds, periodic
## spatial 3D bird chirps coming from the park trees, and a tiny animated
## bumblebee lazily orbiting the sunny edge of the picnic area with a soft spatial buzz.

const WIND_PATH := "res://assets/audio/ambience/park_wind.ogg"
const BIRDS_BED_PATH := "res://assets/audio/ambience/park_birds_bed.ogg"
const BEE_BUZZ_PATH := "res://assets/audio/ambience/bee_buzz.ogg"
const BIRD_CHIRPS := ["bird_chirp_1", "bird_chirp_2", "bird_chirp_3"]

## Seconds between spatial bird chirps in the trees.
@export var bird_interval_min: float = 4.5
@export var bird_interval_max: float = 11.0
## Volume of the background wind and distant bird beds.
@export var wind_volume_db: float = -17.0
@export var birds_bed_volume_db: float = -19.0
## Volume of the tiny spatial wandering bee.
@export var bee_volume_db: float = -22.0

var _tree_spots: Array[Vector3] = []
var _bird_timer: float = 2.5
var _bees: Array[Dictionary] = []
var _birds_bed_player: AudioStreamPlayer
var _night_factor: float = 0.0


func _ready() -> void:
	_start_ambient_bed(WIND_PATH, wind_volume_db)
	_birds_bed_player = _start_ambient_bed(BIRDS_BED_PATH, birds_bed_volume_db)
	_find_tree_canopies()
	_spawn_bees()


## Gently quiets daytime birdsong during deep night while keeping the evening breeze.
func set_night_factor(night: float) -> void:
	_night_factor = clampf(night, 0.0, 1.0)
	if _birds_bed_player:
		_birds_bed_player.volume_db = lerpf(birds_bed_volume_db, -42.0, _night_factor)


func _process(delta: float) -> void:
	if _night_factor < 0.7:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = randf_range(bird_interval_min, bird_interval_max) * lerpf(1.0, 2.2, _night_factor)
			_play_tree_bird()

	for bee in _bees:
		bee.phase += delta * bee.speed
		var t: float = bee.phase
		var center: Vector3 = bee.center
		var r: Vector3 = bee.radius
		var pos := Vector3(
			center.x + sin(t) * r.x + sin(t * 2.3) * 0.18,
			center.y + sin(t * 1.7 + 0.8) * r.y,
			center.z + cos(t * 0.85) * r.z + cos(t * 1.9) * 0.16
		)
		var node: Node3D = bee.node
		var prev := node.global_position
		node.global_position = pos
		var vel := pos - prev
		vel.y = 0.0
		if vel.length_squared() > 1e-8:
			node.rotation.y = atan2(vel.x, vel.z)
		# Rapid cute wing flutter.
		var flap := sin(Time.get_ticks_msec() * 0.065) * 0.65
		(bee.wing_l as Node3D).rotation.z = 0.35 + flap
		(bee.wing_r as Node3D).rotation.z = -0.35 - flap


func _start_ambient_bed(path: String, volume_db: float) -> AudioStreamPlayer:
	var stream := Audio.load_looping(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Ambience" if AudioServer.get_bus_index("Ambience") != -1 else &"Master"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func _find_tree_canopies() -> void:
	var park := get_parent()
	if park:
		for child in park.get_children():
			if child is Node3D and child.name.begins_with("Tree"):
				_tree_spots.append((child as Node3D).global_position + Vector3(0, 3.2, 0))
	if _tree_spots.is_empty():
		_tree_spots = [
			Vector3(-5, 3.2, -6),
			Vector3(4, 3.2, -7.5),
			Vector3(-9, 3.2, 1),
			Vector3(8, 3.2, -2),
		]


func _play_tree_bird() -> void:
	if _tree_spots.is_empty():
		return
	var spot: Vector3 = _tree_spots.pick_random()
	var chirp: String = BIRD_CHIRPS.pick_random()
	Audio.play_3d(chirp, spot, randf_range(-3.0, 1.5))


func _spawn_bees() -> void:
	var bee_stream := Audio.load_looping(BEE_BUZZ_PATH)
	# A single gentle park bee drifting around the sunny edge of the picnic area,
	# far enough away that you only faintly catch its buzz when it passes by.
	var configs := [
		{"center": Vector3(-2.1, 1.35, -0.6), "radius": Vector3(1.1, 0.25, 1.3), "speed": 0.42, "phase": 0.0},
	]
	for cfg in configs:
		var bee_root := Node3D.new()
		bee_root.name = "ParkBee"
		add_child(bee_root)
		bee_root.global_position = cfg.center

		# Tiny cute yellow-and-black bee body.
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.009
		body_mesh.height = 0.024
		body_mesh.radial_segments = 8
		body_mesh.rings = 4
		var yellow := StandardMaterial3D.new()
		yellow.albedo_color = Color(0.98, 0.78, 0.12)
		body_mesh.material = yellow
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.rotation.x = PI * 0.5
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bee_root.add_child(body)

		var stripe_mesh := CylinderMesh.new()
		stripe_mesh.top_radius = 0.0095
		stripe_mesh.bottom_radius = 0.0095
		stripe_mesh.height = 0.005
		stripe_mesh.radial_segments = 8
		var black := StandardMaterial3D.new()
		black.albedo_color = Color(0.1, 0.08, 0.06)
		stripe_mesh.material = black
		for z_off: float in [-0.004, 0.004]:
			var stripe := MeshInstance3D.new()
			stripe.mesh = stripe_mesh
			stripe.rotation.x = PI * 0.5
			stripe.position.z = z_off
			stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bee_root.add_child(stripe)

		# Translucent fluttering wings.
		var wing_mesh := BoxMesh.new()
		wing_mesh.size = Vector3(0.016, 0.001, 0.009)
		var wing_mat := StandardMaterial3D.new()
		wing_mat.albedo_color = Color(0.95, 0.98, 1.0, 0.55)
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wing_mesh.material = wing_mat

		var wing_l := MeshInstance3D.new()
		wing_l.mesh = wing_mesh
		wing_l.position = Vector3(-0.009, 0.007, 0)
		wing_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bee_root.add_child(wing_l)

		var wing_r := MeshInstance3D.new()
		wing_r.mesh = wing_mesh
		wing_r.position = Vector3(0.009, 0.007, 0)
		wing_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bee_root.add_child(wing_r)

		if bee_stream:
			var buzz := AudioStreamPlayer3D.new()
			buzz.stream = bee_stream
			buzz.bus = &"Ambience" if AudioServer.get_bus_index("Ambience") != -1 else &"Master"
			buzz.volume_db = bee_volume_db
			buzz.unit_size = 0.18
			buzz.max_distance = 2.6
			buzz.pitch_scale = randf_range(0.96, 1.04)
			bee_root.add_child(buzz)
			buzz.play(randf_range(0.0, 2.0))

		_bees.append({
			"node": bee_root,
			"wing_l": wing_l,
			"wing_r": wing_r,
			"center": cfg.center,
			"radius": cfg.radius,
			"speed": cfg.speed,
			"phase": cfg.phase,
		})
