class_name Tower
extends Node3D
## Base for every tower: shoots the enemy furthest along the path within
## range. Tower scenes put this on their root and set the base stats; active
## cards modify them (see the get_*() functions).

@export var display_name: String = "Tower"
## Used by cards to target this tower type, e.g. "archer.damage".
@export var kind: String = "archer"
@export var cost: int = 50
## Reach in metres (one board tile is 0.08 m).
@export var attack_range: float = 0.25
@export var damage: float = 1.0
## Seconds between shots.
@export var fire_interval: float = 0.8
## Damages every enemy this close to the impact. 0 hits only the target.
@export var splash_radius: float = 0.0
## Damage multipliers against particular enemy types, e.g. {"tank": 1.5}.
@export var bonus_damage_vs: Dictionary[String, float] = {}
@export var projectile_speed: float = 0.8
@export var projectile_color: Color = Color.WHITE
## Height shots leave from, relative to the tower's base.
@export var muzzle_height: float = 0.1

## Set by whoever builds the tower. Null means no cards apply.
var upgrades: Upgrades
## Previews (shop display, placement ghosts) never shoot.
var preview: bool = false
var _cooldown: float = 0.0


## Turns this into a display copy that doesn't shoot. Ghostly copies are
## see-through, for showing where a tower would go.
func make_preview(ghostly: bool) -> void:
	preview = true
	if ghostly:
		for mesh in find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).transparency = 0.45


func get_cost() -> int:
	return roundi(cost * _mult("cost"))


func get_range() -> float:
	return attack_range * _mult("range")


func get_damage() -> float:
	return (damage + _bonus("damage")) * _mult("damage")


func get_fire_interval() -> float:
	return fire_interval / _mult("fire_rate")


func get_splash_radius() -> float:
	return splash_radius * _mult("splash_radius")


## Fire damage per second each hit sets burning.
func get_burn_dps() -> float:
	return _bonus("burn_dps")


## How much each hit slows its target (0.4 = 40% slower).
func get_slow() -> float:
	return clampf(_bonus("slow"), 0.0, 0.9)


## A few lines summing up the tower's current stats, cards included.
func describe(tile_size: float) -> String:
	var lines: Array[String] = [
		"%s  -  %d gold" % [display_name, get_cost()],
		"Damage %s   Attacks/s %.1f   Range %.1f tiles" % [
			_number(get_damage()), 1.0 / get_fire_interval(), get_range() / tile_size
		],
	]
	if get_splash_radius() > 0.0:
		lines.append("Splash: hits everything within %.1f tiles" % (get_splash_radius() / tile_size))
	for enemy_kind in bonus_damage_vs:
		lines.append("%sx damage vs %ss" % [_number(bonus_damage_vs[enemy_kind]), enemy_kind])
	if get_burn_dps() > 0.0:
		lines.append("Sets enemies on fire (%s damage/s)" % _number(get_burn_dps()))
	if get_slow() > 0.0:
		lines.append("Slows enemies by %d%%" % roundi(get_slow() * 100.0))
	return "\n".join(lines)


func _process(delta: float) -> void:
	if preview:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target:
		_cooldown = get_fire_interval()
		_fire(target)


func _find_target() -> Enemy:
	var reach := get_range()
	var best: Enemy = null
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() > reach:
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _fire(target: Enemy) -> void:
	var projectile := Projectile.new()
	projectile.setup(target, self)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * muzzle_height


func _number(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func _mult(stat: String) -> float:
	return upgrades.multiplier("tower", kind, stat) if upgrades else 1.0


func _bonus(stat: String) -> float:
	return upgrades.bonus("tower", kind, stat) if upgrades else 0.0
