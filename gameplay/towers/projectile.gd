class_name Projectile
extends Node3D
## A shot that homes in on its target. If the target dies first it flies on
## to where the target was and lands there.
##
## Looks: the tower's projectile_model if it has one (arrow, cannonball),
## turned to face where it's flying, otherwise a glowing orb with a trail.
## Burning and chilling shots leave a fire or frost trail. Splash shots fly
## in an arc and explode with a ring showing the splash radius.
##
## Card effects carried by the shot: chain (jumps to more enemies), cluster
## (smaller explosions around a splash hit), pierce (ignores armour) and
## knockback (pushes enemies back along the path).

const RADIUS := 0.006
const BURN_DURATION := 3.0
const SLOW_DURATION := 2.0
const EXPLOSION_COLOR := Color(1.0, 0.6, 0.2)
const CHAIN_COLOR := Color(0.6, 0.85, 1.0)
const SMOKE_TRAIL_COLOR := Color(0.55, 0.55, 0.55, 0.7)
const STREAK_COLOR := Color(1.0, 1.0, 1.0, 0.6)
## How far a chain can jump, and how much damage each jump keeps.
const CHAIN_RANGE := 0.12
const CHAIN_FALLOFF := 0.7
## Cluster explosions: their size and damage relative to the main blast,
## how far out they land, and the delay between them.
const CLUSTER_SCALE := 0.5
const CLUSTER_SPREAD := 0.8
const CLUSTER_DELAY := 0.12

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
var _chain: int
var _cluster: int
var _pierce: bool
var _knockback: float
var _explodes: bool
var _landed := false


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
	_chain = tower.get_chain()
	_cluster = tower.get_cluster()
	_pierce = tower.get_pierce()
	_knockback = tower.get_knockback()
	_explodes = tower.splash_explodes

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
	# Every shot leaves something behind: fire or frost when it carries them,
	# sparkles for magic, smoke for heavy shots, a faint streak for arrows.
	if tower.projectile_model == null or _burn_dps > 0.0 or _slow > 0.0:
		_trail = Effects.trail(_color)
	elif _splash_radius > 0.0:
		_trail = Effects.trail(SMOKE_TRAIL_COLOR, 0.007, 0.4)
	else:
		_trail = Effects.trail(STREAK_COLOR, 0.003, 0.12)
	add_child(_trail)


func _ready() -> void:
	_start = global_position


func _process(delta: float) -> void:
	if _landed:
		return
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
	_landed = true
	Effects.stop_trail(_trail)
	for child in get_children():
		(child as Node3D).hide()
	if _splash_radius > 0.0:
		_explode(_aim, _splash_radius, 1.0)
		if _cluster > 0:
			# The little bombs go off one after another around the blast;
			# the shot stays around (hidden) until they're done.
			var tween := create_tween()
			for i in _cluster:
				var angle := TAU * i / _cluster + randf() * 0.5
				var spot := _aim + Vector3(cos(angle), 0, sin(angle)) * _splash_radius * CLUSTER_SPREAD
				tween.tween_interval(CLUSTER_DELAY)
				tween.tween_callback(_explode.bind(spot, _splash_radius * CLUSTER_SCALE, CLUSTER_SCALE))
			tween.tween_callback(queue_free)
			return
	else:
		var hit: Array[Enemy] = []
		if is_instance_valid(_target) and not _target.is_dead():
			_hit(_target, 1.0)
			hit.append(_target)
		Effects.burst(get_parent(), _aim, _color, 10, 0.005, 0.1, 0.3)
		_chain_from(_aim, hit)
	queue_free()


## Damages everything within `radius` of `at`, with a blast (or a dust
## cloud) and a ring.
func _explode(at: Vector3, radius: float, strength: float) -> void:
	var world := get_parent()
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(at) <= radius:
			_hit(enemy, strength)
	if _explodes:
		Effects.explosion(world, at, radius)
	else:
		Effects.impact(world, at, radius)
	Effects.ring(world, at + Vector3.DOWN * 0.015, radius, Color(EXPLOSION_COLOR, 0.2))


## Chain lightning: jumps from `from` to the nearest enemy not hit yet,
## weaker each time, up to _chain times.
func _chain_from(from: Vector3, hit: Array[Enemy]) -> void:
	var strength := 1.0
	for i in _chain:
		var next: Enemy = null
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy in hit or enemy.is_dead():
				continue
			var distance := enemy.global_position.distance_to(from)
			if distance <= CHAIN_RANGE and (next == null or distance < next.global_position.distance_to(from)):
				next = enemy
		if next == null:
			return
		strength *= CHAIN_FALLOFF
		var to := next.global_position + Vector3.UP * 0.02
		Effects.zap(get_parent(), from, to, CHAIN_COLOR)
		_hit(next, strength)
		hit.append(next)
		from = to


func _hit(enemy: Enemy, strength: float) -> void:
	if _burn_dps > 0.0:
		enemy.ignite(_burn_dps, BURN_DURATION)
	if _slow > 0.0:
		enemy.chill(_slow, SLOW_DURATION)
	if _knockback > 0.0:
		enemy.knock_back(_knockback * strength)
	# Piercing shots ignore resistances, which are looked up by source.
	var source := "" if _pierce else _source
	enemy.take_damage(_damage * strength * _bonus_damage_vs.get(enemy.kind, 1.0), source)


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
