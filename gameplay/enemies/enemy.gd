class_name Enemy
extends PathFollow3D
## Something that hops along the board's enemy path. Each enemy type is its
## own scene using this script (blob.tscn, tank.tscn). The WaveSpawner calls
## setup() and adds it as a child of the board's Path3D.

signal reached_end
signal died(reward: int)

const BURN_TINT := Color(1.0, 0.45, 0.1)
const SLOW_TINT := Color(0.55, 0.85, 1.0)

## Used by cards to target this enemy type, e.g. "tank.damage_taken".
@export var kind: String = "blob"
@export var base_health: float = 4.0
## Metres per second along the path.
@export var base_speed: float = 0.055
## Gold paid out when killed.
@export var base_reward: int = 6
@export var hop_height: float = 0.012

var max_health: float
var health: float
var speed: float
var reward: int
## Multiplies all damage this enemy takes.
var damage_taken: float = 1.0

var _dead := false
var _time := randf() * TAU
var _burn_dps: float = 0.0
var _burn_time: float = 0.0
var _slow: float = 0.0
var _slow_time: float = 0.0
var _body_material: StandardMaterial3D
var _body_color: Color

@onready var _body: MeshInstance3D = $Body
@onready var _health_fill: Node3D = $HealthBar/Fill
@onready var _body_rest_y: float = _body.position.y
@onready var _fill_width: float = _health_fill.scale.x


## Applies wave scaling and active cards. Call before adding to the tree.
func setup(health_scale: float, speed_scale: float, upgrades: Upgrades) -> void:
	var mult := func(stat: String) -> float:
		return upgrades.multiplier("enemy", kind, stat) if upgrades else 1.0
	max_health = base_health * health_scale * mult.call("health")
	speed = base_speed * speed_scale * mult.call("speed")
	reward = roundi(base_reward * mult.call("reward"))
	damage_taken = mult.call("damage_taken")


func _ready() -> void:
	if max_health <= 0.0:
		setup(1.0, 1.0, null)
	health = max_health
	add_to_group("enemies")
	_body_material = (_body.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_body_color = _body_material.albedo_color
	_body.material_override = _body_material


func _process(delta: float) -> void:
	var slowed := _slow_time > 0.0
	progress += speed * (1.0 - _slow if slowed else 1.0) * delta
	if progress_ratio >= 1.0:
		_dead = true
		reached_end.emit()
		queue_free()
		return
	_slow_time -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta)
	_time += delta
	_body.position.y = _body_rest_y + absf(sin(_time * 9.0)) * hop_height
	_update_tint()


func is_dead() -> bool:
	return _dead


func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount * damage_taken
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_health_fill.scale.x = _fill_width * ratio
	_health_fill.position.x = -_fill_width * (1.0 - ratio) * 0.5
	if health <= 0.0:
		_dead = true
		died.emit(reward)
		queue_free()


## Sets the enemy on fire. A stronger burn replaces a weaker one.
func ignite(damage_per_second: float, duration: float) -> void:
	_burn_dps = maxf(damage_per_second, _burn_dps if _burn_time > 0.0 else 0.0)
	_burn_time = maxf(_burn_time, duration)


## Slows the enemy by a fraction (0.4 = 40% slower). The strongest slow wins.
func chill(fraction: float, duration: float) -> void:
	_slow = maxf(fraction, _slow if _slow_time > 0.0 else 0.0)
	_slow_time = maxf(_slow_time, duration)


func _update_tint() -> void:
	var color := _body_color
	if _burn_time > 0.0:
		color = color.lerp(BURN_TINT, 0.6)
	elif _slow_time > 0.0:
		color = color.lerp(SLOW_TINT, 0.6)
	_body_material.albedo_color = color
