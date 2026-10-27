class_name Projectile
extends Node3D
## A shot that homes in on its target. If the target dies first it flies on
## to where the target was and lands there.
##
## Looks: the tower's projectile_model if it has one (arrow, cannonball),
## turned to face where it's flying, otherwise a glowing orb with a trail.
## Burning and chilling shots leave a fire or frost trail. Splash shots fly
## in an arc and explode with a ring showing the splash radius.

const RADIUS := 0.006
const BURN_DURATION := 3.0
const SLOW_DURATION := 2.0
const EXPLOSION_COLOR := Color(1.0, 0.6, 0.2)
const SMOKE_COLOR := Color(0.45, 0.45, 0.48, 0.8)

var _target: Enemy
var _aim: Vector3
var _start: Vector3
var _travelled: float = 0.0
var _arc_height: float
var _damage: float
var _splash_radius: float
var _speed: float
var _burn_dps: float
var _slow: float
var _bonus_damage_vs: Dictionary[String, float]
var _color: Color
var _source: String
var _trail: CPUParticles3D


## Takes the firing tower's current stats, so cards equipped mid-flight
## don't change a shot already in the air.
func setup(target: Enemy, tower: Tower) -> void:
	_target = target
	_aim = _target_point()
	_damage = tower.get_damage()
	_splash_radius = tower.get_splash_radius()
	_speed = tower.projectile_speed
	_burn_dps = tower.get_burn_dps()
	_slow = tower.get_slow()
	_bonus_damage_vs = tower.bonus_damage_vs
	_arc_height = tower.projectile_arc
	_source = tower.kind

	_color = tower.projectile_color
	if _burn_dps > 0.0:
		_color = Enemy.BURN_TINT
	elif _slow > 0.0:
		_color = Enemy.SLOW_TINT
	if tower.projectile_model:
		var model: Node3D = tower.projectile_model.instantiate()
		model.scale = Vector3.ONE * tower.projectile_model_scale
		add_child(model)
	else:
		add_child(_orb())
	if tower.projectile_model == null or _burn_dps > 0.0 or _slow > 0.0:
		_trail = Effects.trail(_color)
		add_child(_trail)


func _ready() -> void:
	_start = global_position


func _process(delta: float) -> void:
	if is_instance_valid(_target) and not _target.is_dead():
		_aim = _target_point()
	_travelled += _speed * delta
	var total := _start.distance_to(_aim)
	var t := clampf(_travelled / maxf(total, 0.001), 0.0, 1.0)
	var next := _start.lerp(_aim, t) + Vector3.UP * _arc_height * 4.0 * t * (1.0 - t)
	if next.distance_squared_to(global_position) > 1e-10:
		# Kenney ammo models point along +Z.
		look_at(next, Vector3.UP, true)
	global_position = next
	if t >= 1.0:
		_land()


func _target_point() -> Vector3:
	return _target.global_position + Vector3.UP * 0.02


func _land() -> void:
	var world := get_parent()
	if _splash_radius > 0.0:
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(_aim) <= _splash_radius:
				_hit(enemy)
		Effects.burst(world, _aim, EXPLOSION_COLOR, 24, 0.01, 0.2)
		Effects.burst(world, _aim, SMOKE_COLOR, 12, 0.014, 0.08, 0.7)
		Effects.ring(world, _aim + Vector3.DOWN * 0.015, _splash_radius, Color(EXPLOSION_COLOR, 0.6))
	else:
		if is_instance_valid(_target):
			_hit(_target)
		Effects.burst(world, _aim, _color, 10, 0.005, 0.1, 0.3)
	Effects.stop_trail(_trail)
	queue_free()


func _hit(enemy: Enemy) -> void:
	if _burn_dps > 0.0:
		enemy.ignite(_burn_dps, BURN_DURATION)
	if _slow > 0.0:
		enemy.chill(_slow, SLOW_DURATION)
	enemy.take_damage(_damage * _bonus_damage_vs.get(enemy.kind, 1.0), _source)


func _orb() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = _color
	material.emission_enabled = true
	material.emission = _color
	material.emission_energy_multiplier = 2.0
	sphere.material = material
	var orb := MeshInstance3D.new()
	orb.mesh = sphere
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return orb
