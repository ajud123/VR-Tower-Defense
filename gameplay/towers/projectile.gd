class_name Projectile
extends MeshInstance3D
## A shot that homes in on its target. If the target dies first it flies on
## to where the target was and lands there.

const RADIUS := 0.006
const BURN_DURATION := 3.0
const SLOW_DURATION := 2.0

var _target: Enemy
var _aim: Vector3
var _damage: float
var _splash_radius: float
var _speed: float
var _burn_dps: float
var _slow: float
var _bonus_damage_vs: Dictionary[String, float]


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

	var color := tower.projectile_color
	if _burn_dps > 0.0:
		color = Enemy.BURN_TINT
	elif _slow > 0.0:
		color = Enemy.SLOW_TINT
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS * (1.6 if _splash_radius > 0.0 else 1.0)
	sphere.height = sphere.radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	sphere.material = material
	mesh = sphere
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if is_instance_valid(_target) and not _target.is_dead():
		_aim = _target_point()
	var to_aim := _aim - global_position
	var step := _speed * delta
	if to_aim.length() <= step:
		_land()
	else:
		global_position += to_aim.normalized() * step


func _target_point() -> Vector3:
	return _target.global_position + Vector3.UP * 0.016


func _land() -> void:
	if _splash_radius > 0.0:
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(_aim) <= _splash_radius:
				_hit(enemy)
	elif is_instance_valid(_target):
		_hit(_target)
	queue_free()


func _hit(enemy: Enemy) -> void:
	if _burn_dps > 0.0:
		enemy.ignite(_burn_dps, BURN_DURATION)
	if _slow > 0.0:
		enemy.chill(_slow, SLOW_DURATION)
	enemy.take_damage(_damage * _bonus_damage_vs.get(enemy.kind, 1.0))
