@tool
class_name ParkClouds
extends Node3D
## Cutesy stylized low-poly fantasy clouds drifting lazily across the park sky.
## Automatically tinted by DayNightCycle: fluffy cream-white by day, cotton-candy
## peach-gold at sunrise/sunset, and soft moonlit indigo at night.

const CLOUD_COUNT := 16
const SKY_EXTENT := 56.0
const CLOUD_HEIGHT_MIN := 15.0
const CLOUD_HEIGHT_MAX := 24.0

var _cloud_mat: StandardMaterial3D
var _puff_mesh: SphereMesh
var _clouds: Array[Dictionary] = []
var _container: Node3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("park_clouds")
	_build_clouds()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var t := Time.get_ticks_msec() * 0.001
	for c in _clouds:
		var node: Node3D = c.node
		node.position.x += c.speed * delta
		if node.position.x > SKY_EXTENT:
			node.position.x = -SKY_EXTENT
		node.position.y = c.base_y + sin(t * 0.35 + c.phase) * 0.25


## Updates the clouds' tint and soft ambient glow to match the time of day.
func set_tint(albedo: Color, glow_color: Color, glow_energy: float) -> void:
	if _cloud_mat == null:
		return
	_cloud_mat.albedo_color = albedo
	_cloud_mat.emission_enabled = glow_energy > 0.01
	_cloud_mat.emission = glow_color
	_cloud_mat.emission_energy_multiplier = glow_energy


func _build_clouds() -> void:
	if _container:
		_container.queue_free()
	_container = Node3D.new()
	_container.name = "Clouds"
	add_child(_container)
	_clouds.clear()

	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.albedo_color = Color(0.99, 0.98, 0.96)
	_cloud_mat.roughness = 1.0
	_cloud_mat.metallic = 0.0
	_cloud_mat.disable_fog = true
	_cloud_mat.emission_enabled = true
	_cloud_mat.emission = Color(0.92, 0.95, 1.0)
	_cloud_mat.emission_energy_multiplier = 0.28

	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 1.0
	_puff_mesh.height = 1.65  # Gently squashed vertically for cute plush clouds.
	_puff_mesh.radial_segments = 10
	_puff_mesh.rings = 5
	_puff_mesh.material = _cloud_mat

	var rng := RandomNumberGenerator.new()
	rng.seed = 77312

	for i in CLOUD_COUNT:
		var cloud := Node3D.new()
		var angle := TAU * float(i) / float(CLOUD_COUNT) + rng.randf_range(-0.22, 0.22)
		var dist := rng.randf_range(16.0, 48.0)
		var base_y := rng.randf_range(CLOUD_HEIGHT_MIN, CLOUD_HEIGHT_MAX)
		cloud.position = Vector3(cos(angle) * dist, base_y, sin(angle) * dist)
		cloud.rotation.y = rng.randf() * TAU
		var overall_scale := rng.randf_range(1.15, 2.2)
		cloud.scale = Vector3.ONE * overall_scale
		_container.add_child(cloud)

		# Classic fluffy fantasy cloud silhouette: big plump center + flanking puffs + cute top crown.
		_add_puff(cloud, Vector3(0.0, 0.12, 0.0), Vector3(1.25, 1.05, 1.05))
		_add_puff(cloud, Vector3(-1.05, -0.08, 0.08), Vector3(0.92, 0.78, 0.85))
		_add_puff(cloud, Vector3(1.05, -0.1, -0.06), Vector3(0.95, 0.8, 0.85))
		_add_puff(cloud, Vector3(-0.45, 0.42, -0.12), Vector3(0.75, 0.68, 0.72))
		_add_puff(cloud, Vector3(0.5, 0.35, 0.14), Vector3(0.72, 0.64, 0.7))
		if rng.randf() < 0.65:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			_add_puff(cloud, Vector3(side * 1.75, -0.22, rng.randf_range(-0.15, 0.15)), Vector3(0.62, 0.52, 0.58))

		_clouds.append({
			"node": cloud,
			"base_y": base_y,
			"speed": rng.randf_range(0.32, 0.72),
			"phase": rng.randf() * TAU,
		})


func _add_puff(parent: Node3D, at: Vector3, puff_scale: Vector3) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = _puff_mesh
	inst.position = at
	inst.scale = puff_scale
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
