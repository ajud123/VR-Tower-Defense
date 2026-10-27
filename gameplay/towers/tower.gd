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
## What the shot looks like (e.g. an arrow). None means a glowing orb.
@export var projectile_model: PackedScene
@export var projectile_model_scale: float = 0.02
## How high shots arc above a straight line, in metres. 0 flies straight.
@export var projectile_arc: float = 0.0
## Height shots leave from, relative to the tower's base.
@export var muzzle_height: float = 0.1
## Optional weapon model that turns to face what the tower shoots at.
## Kenney weapons point along +Z.
@export var turret: Node3D

## Set by whoever builds the tower. Null means no cards apply.
var upgrades: Upgrades
## Gold paid for it, for working out what selling it gives back.
var paid: int = 0
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


## The tower's current stats, cards included, as {"icon", "text"} rows for
## the shop's stat board. Icon keys are from gameplay/icons/.
func stat_rows(tile_size: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"icon": "damage", "text": _number(get_damage())},
		{"icon": "fire_rate", "text": "%.1f/s" % (1.0 / get_fire_interval())},
		{"icon": "range", "text": "%.1f" % (get_range() / tile_size)},
	]
	if get_splash_radius() > 0.0:
		rows.append({"icon": "splash_radius", "text": "%.1f" % (get_splash_radius() / tile_size)})
	for enemy_kind in bonus_damage_vs:
		rows.append({"icon": enemy_kind, "text": "x" + _number(bonus_damage_vs[enemy_kind])})
	if get_burn_dps() > 0.0:
		rows.append({"icon": "burn_dps", "text": "%s/s" % _number(get_burn_dps())})
	if get_slow() > 0.0:
		rows.append({"icon": "slow", "text": "-%d%%" % roundi(get_slow() * 100.0)})
	return rows


func _process(delta: float) -> void:
	if preview:
		return
	_cooldown -= delta
	var target := _find_target()
	if target:
		_aim_at(target)
		if _cooldown <= 0.0:
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


func _aim_at(target: Enemy) -> void:
	if turret == null:
		return
	var offset := turret.global_position.direction_to(target.global_position)
	turret.global_rotation.y = atan2(offset.x, offset.z)


func _fire(target: Enemy) -> void:
	var projectile := Projectile.new()
	projectile.setup(target, self)
	# Placed before it enters the tree, so it knows where it started from.
	projectile.position = position + Vector3.UP * muzzle_height
	get_parent().add_child(projectile)


func _number(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func _mult(stat: String) -> float:
	return upgrades.multiplier("tower", kind, stat) if upgrades else 1.0


func _bonus(stat: String) -> float:
	return upgrades.bonus("tower", kind, stat) if upgrades else 0.0
