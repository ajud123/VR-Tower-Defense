class_name Enemy
extends PathFollow3D
## Something that walks along the board's enemy path. Each enemy type is its
## own scene using this script (blob.tscn, tank.tscn, ghost.tscn, ...). The
## WaveSpawner calls
## setup() and adds it as a child of the board's Path3D.
##
## The scene's Body is an animated Kenney character (with "walk" and "die"
## animations). It turns to face where it's going, and is tinted while
## burning (with flames) or slowed. It leaves a puff of smoke when it dies.

signal reached_end
signal died(reward: int)

const BURN_TINT := Color(1.0, 0.45, 0.1)
const SLOW_TINT := Color(0.55, 0.85, 1.0)
## How strongly a burn or slow tints the body.
const TINT_STRENGTH := 0.45
## The walk animation plays at normal speed at this many metres per second.
const WALK_ANIMATION_SPEED := 0.05
## Kenney characters face +Z; turn them to face along the path.
const TURN_SPEED := 10.0
const DEATH_SMOKE := Color(0.85, 0.85, 0.85, 0.8)

## Used by cards to target this enemy type, e.g. "tank.damage_taken".
@export var kind: String = "blob"
@export var base_health: float = 4.0
## Metres per second along the path.
@export var base_speed: float = 0.055
## Gold paid out when killed.
@export var base_reward: int = 6
## Lives lost when it reaches the castle.
@export var lives_cost: int = 1
## Damage multipliers against particular tower kinds, e.g. {"archer": 0.5}
## takes half damage from archers.
@export var resistances: Dictionary[String, float] = {}
## Heals this fraction of its max health per second.
@export var regen_per_second: float = 0.0
## See-through amount of the body, e.g. for ghosts.
@export_range(0.0, 1.0) var body_transparency: float = 0.0

var max_health: float
var health: float
var speed: float
var reward: int
## Multiplies all damage this enemy takes.
var damage_taken: float = 1.0
## Extra damage taken while slowed (0.5 = +50%), from the Shatter card.
var shatter: float = 0.0

var _dead := false
var _burn_dps: float = 0.0
var _burn_time: float = 0.0
var _slow: float = 0.0
var _slow_time: float = 0.0
var _tint := StandardMaterial3D.new()
var _flames: CPUParticles3D
var _last_position: Vector3

@onready var _body: Node3D = $Body
@onready var _animation: AnimationPlayer = _body.find_child("AnimationPlayer", true, false)
@onready var _health_bar: Node3D = $HealthBar
@onready var _health_fill: Node3D = $HealthBar/Fill
@onready var _fill_width: float = _health_fill.scale.x


## Applies wave scaling and active cards. Call before adding to the tree.
func setup(health_scale: float, speed_scale: float, upgrades: Upgrades) -> void:
	var mult := func(stat: String) -> float:
		return upgrades.multiplier("enemy", kind, stat) if upgrades else 1.0
	max_health = base_health * health_scale * mult.call("health")
	speed = base_speed * speed_scale * mult.call("speed")
	reward = roundi(base_reward * mult.call("reward"))
	damage_taken = mult.call("damage_taken")
	shatter = upgrades.bonus("enemy", kind, "shatter") if upgrades else 0.0


func _ready() -> void:
	if max_health <= 0.0:
		setup(1.0, 1.0, null)
	health = max_health
	add_to_group("enemies")
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh: MeshInstance3D in _body.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _tint
		mesh.transparency = body_transparency
	if _animation:
		# The Kenney walk cycles are imported as play-once; keep them going.
		_animation.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
		_animation.play("walk")
	_flames = Effects.trail(BURN_TINT, 0.006, 0.4)
	_flames.gravity = Vector3(0, 0.12, 0)
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 0.01
	_flames.position.y = 0.02
	_flames.emitting = false
	add_child(_flames)
	_last_position = global_position


func _process(delta: float) -> void:
	if _dead:
		return
	var slowed := _slow_time > 0.0
	var current_speed := speed * (1.0 - _slow if slowed else 1.0)
	progress += current_speed * delta
	if progress_ratio >= 1.0:
		_dead = true
		reached_end.emit()
		queue_free()
		return
	_slow_time -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta)
	if regen_per_second > 0.0 and not _dead and health < max_health:
		health = minf(health + max_health * regen_per_second * delta, max_health)
		_update_health_bar()
	_face_movement(delta)
	if _animation:
		_animation.speed_scale = current_speed / WALK_ANIMATION_SPEED
	_update_tint()


func is_dead() -> bool:
	return _dead


## `source` is the kind of tower that dealt it ("archer", ...), for
## resistances; burns and other effects pass "".
func take_damage(amount: float, source: String = "") -> void:
	if _dead:
		return
	var slowed_extra := 1.0 + shatter if _slow_time > 0.0 else 1.0
	health -= amount * damage_taken * slowed_extra * resistances.get(source, 1.0)
	_update_health_bar()
	if health <= 0.0:
		_dead = true
		died.emit(reward)
		_die()


## Sets the enemy on fire. A stronger burn replaces a weaker one.
func ignite(damage_per_second: float, duration: float) -> void:
	_burn_dps = maxf(damage_per_second, _burn_dps if _burn_time > 0.0 else 0.0)
	_burn_time = maxf(_burn_time, duration)


## Slows the enemy by a fraction (0.4 = 40% slower). The strongest slow wins.
## Pushes it back along the path by `distance` metres. Bosses (anything
## costing more than one life) stand their ground.
func knock_back(distance: float) -> void:
	if _dead or lives_cost > 1:
		return
	progress = maxf(progress - distance, 0.0)


func chill(fraction: float, duration: float) -> void:
	_slow = maxf(fraction, _slow if _slow_time > 0.0 else 0.0)
	_slow_time = maxf(_slow_time, duration)


func _update_health_bar() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_health_fill.scale.x = _fill_width * ratio
	_health_fill.position.x = -_fill_width * (1.0 - ratio) * 0.5


## Falls over, then goes away. Towers already ignore it (is_dead()).
func _die() -> void:
	remove_from_group("enemies")
	_health_bar.hide()
	_tint.albedo_color.a = 0.0
	var linger := 0.0
	if _animation and _animation.has_animation("die"):
		_animation.speed_scale = 1.0
		_animation.play("die")
		linger = minf(_animation.current_animation_length, 1.0)
	_flames.emitting = false
	get_tree().create_timer(linger + 0.3).timeout.connect(_vanish)


func _vanish() -> void:
	Effects.burst(get_parent(), global_position + Vector3.UP * 0.015, DEATH_SMOKE, 14, 0.012, 0.06, 0.6)
	queue_free()


func _face_movement(delta: float) -> void:
	var step := global_position - _last_position
	_last_position = global_position
	step.y = 0.0
	if step.length_squared() < 1e-10:
		return
	var target := atan2(step.x, step.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target, minf(TURN_SPEED * delta, 1.0))


func _update_tint() -> void:
	_flames.emitting = _burn_time > 0.0
	var color := Color(0, 0, 0, 0)
	if _burn_time > 0.0:
		color = Color(BURN_TINT, TINT_STRENGTH)
	elif _slow_time > 0.0:
		color = Color(SLOW_TINT, TINT_STRENGTH)
	_tint.albedo_color = color
