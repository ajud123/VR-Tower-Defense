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
## What a splash hit looks like: a fiery explosion, or a dust cloud with
## flying rocks (for things that just land hard, like boulders).
@export var splash_explodes: bool = true
## Height shots leave from, relative to the tower's base.
@export var muzzle_height: float = 0.1
## Optional weapon model that turns to face what the tower shoots at.
## Kenney weapons point along +Z.
@export var turret: Node3D

@export_group("Upgrades")
## Maximum upgrade level achievable by stacking towers.
@export var max_level: int = 3
## Model scene to insert when stacking/upgrading (e.g. middle tower section).
@export var upgrade_piece: PackedScene
## Height added to the tower in Model-local units per upgrade tier.
@export var upgrade_piece_height: float = 0.6
## Nodes in Model that move upwards when an upgrade piece is inserted.
@export var top_nodes: Array[Node3D] = []

## Current tower level: 1 = base, 2+ = upgraded.
var level: int = 1
## Set by whoever builds the tower. Null means no cards apply.
var upgrades: Upgrades
## Gold paid for it, for working out what selling it gives back.
var paid: int = 0
## Previews (shop display, placement ghosts) never shoot.
var preview: bool = false
var _cooldown: float = 0.0
var _level_label: Label3D


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
	var base := attack_range * (1.0 + 0.15 * (level - 1))
	return base * _mult("range")


## What the range would be if this tower is upgraded to the next level.
func get_upgraded_range() -> float:
	var next_level := mini(level + 1, max_level)
	var base := attack_range * (1.0 + 0.15 * (next_level - 1))
	return base * _mult("range")


func get_damage() -> float:
	var base := damage * (1.0 + 0.75 * (level - 1)) + _bonus("damage")
	return base * _mult("damage")


func get_fire_interval() -> float:
	var base := fire_interval / (1.0 + 0.2 * (level - 1))
	return base / _mult("fire_rate")


func get_splash_radius() -> float:
	var base := splash_radius * (1.0 + 0.2 * (level - 1))
	return base * _mult("splash_radius")


func can_upgrade() -> bool:
	return not preview and level < max_level


## Upgrades this tower by stacking another piece and boosting stats.
func upgrade(additional_cost: int = 0) -> void:
	if not can_upgrade():
		return
	level += 1
	paid += additional_cost
	_apply_upgrade_model()
	_update_level_badge()
	_play_upgrade_effects()


## Height of the top of the tower in board-local space, for positioning placement ghosts on top.
func get_top_height() -> float:
	var model := get_node_or_null("Model") as Node3D
	if model:
		var max_y := 0.0
		for child in model.get_children():
			if child is Node3D:
				max_y = maxf(max_y, (child as Node3D).position.y)
		return (max_y + 0.4) * model.scale.y
	return 0.08 * level


func _apply_upgrade_model() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return

	var nodes_to_shift: Array[Node3D] = []
	for node in top_nodes:
		if is_instance_valid(node):
			nodes_to_shift.append(node)

	if nodes_to_shift.is_empty():
		if turret and turret != model:
			nodes_to_shift.append(turret)
		else:
			for child in model.get_children():
				if child is Node3D and (child as Node3D).position.y > 0.01:
					nodes_to_shift.append(child as Node3D)

	var insert_y := INF
	for node in nodes_to_shift:
		insert_y = minf(insert_y, node.position.y)
	if is_inf(insert_y):
		insert_y = upgrade_piece_height * (level - 2)

	if upgrade_piece:
		var new_piece: Node3D = upgrade_piece.instantiate()
		new_piece.position = Vector3(0, insert_y, 0)
		model.add_child(new_piece)

		new_piece.scale = Vector3(1.0, 0.01, 1.0)
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(new_piece, "scale", Vector3.ONE, 0.25)
		for node in nodes_to_shift:
			tween.tween_property(node, "position:y", node.position.y + upgrade_piece_height, 0.25)
	else:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(model, "scale:y", model.scale.y * 1.2, 0.25)

	muzzle_height += upgrade_piece_height * model.scale.y


func _update_level_badge() -> void:
	if _level_label == null:
		_level_label = Label3D.new()
		_level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_level_label.no_depth_test = true
		_level_label.font_size = 28
		_level_label.pixel_size = 0.0004
		_level_label.outline_size = 6
		_level_label.outline_modulate = Color(0.1, 0.08, 0.05, 0.9)
		add_child(_level_label)

	_level_label.visible = level > 1
	if level == 2:
		_level_label.text = "LV 2"
		_level_label.modulate = Color(1.0, 0.85, 0.25)
	elif level >= max_level:
		_level_label.text = "LV %d (MAX)" % level
		_level_label.modulate = Color(1.0, 0.65, 0.15)
	else:
		_level_label.text = "LV %d" % level
		_level_label.modulate = Color(1.0, 0.85, 0.25)

	_level_label.position = Vector3(0, muzzle_height + 0.045, 0)


func _play_upgrade_effects() -> void:
	if not is_inside_tree():
		return
	var world := get_tree().current_scene if get_tree() else get_parent()
	if world == null:
		return
	var at := global_position + Vector3.UP * (muzzle_height * 0.5)

	Effects.burst(world, at, Color(1.0, 0.85, 0.2), 24, 0.008, 0.18, 0.6)
	Effects.burst(world, at + Vector3.UP * 0.02, Color(1.0, 1.0, 0.7), 16, 0.005, 0.12, 0.4)
	Effects.ring(world, global_position + Vector3.UP * 0.005, 0.06, Color(1.0, 0.85, 0.2, 0.6))

	var banner := Label3D.new()
	banner.text = "LEVEL %d!" % level if level < max_level else "LEVEL %d (MAX)!" % level
	banner.font_size = 38
	banner.outline_size = 8
	banner.pixel_size = 0.0005
	banner.modulate = Color(1.0, 0.9, 0.3)
	banner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	banner.no_depth_test = true
	world.add_child(banner)
	banner.global_position = global_position + Vector3.UP * (muzzle_height + 0.06)

	var tween := banner.create_tween().set_parallel()
	tween.tween_property(banner, "global_position:y", banner.global_position.y + 0.08, 1.1)
	tween.tween_property(banner, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tween.chain().tween_callback(banner.queue_free)


## Fire damage per second each hit sets burning.
func get_burn_dps() -> float:
	return _bonus("burn_dps")


## How much each hit slows its target (0.4 = 40% slower).
func get_slow() -> float:
	return clampf(_bonus("slow"), 0.0, 0.9)


## Damage per second against one enemy in the way of every shot, counting
## multishot's extra targets. Leaves out splash, burn and chain bonuses,
## which depend on how many enemies get caught.
func get_dps() -> float:
	return get_damage() / get_fire_interval() * (1 + get_multishot())


## Extra enemies each shot jumps on to after hitting (chain lightning).
func get_chain() -> int:
	return roundi(_bonus("chain"))


## Extra targets shot at the same time.
func get_multishot() -> int:
	return roundi(_bonus("multishot"))


## Smaller explosions set off around each splash hit.
func get_cluster() -> int:
	return roundi(_bonus("cluster"))


## Whether shots ignore enemy resistances (armour).
func get_pierce() -> bool:
	return _bonus("pierce") > 0.0


## How far back along the path each hit pushes an enemy, in metres.
func get_knockback() -> float:
	return _bonus("knockback")


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
	if get_multishot() > 0:
		rows.append({"icon": "multishot", "text": "+%d" % get_multishot()})
	if get_chain() > 0:
		rows.append({"icon": "chain", "text": "+%d" % get_chain()})
	if get_cluster() > 0:
		rows.append({"icon": "cluster", "text": "+%d" % get_cluster()})
	if get_pierce():
		rows.append({"icon": "pierce", "text": "yes"})
	if get_knockback() > 0.0:
		rows.append({"icon": "knockback", "text": "%.1f" % (get_knockback() / tile_size)})
	return rows


func _process(delta: float) -> void:
	if preview:
		return
	_cooldown -= delta
	var targets := _targets_in_range()
	if targets.is_empty():
		return
	_aim_at(targets[0])
	if _cooldown <= 0.0:
		_cooldown = get_fire_interval()
		# The furthest along first, plus extras with multishot.
		for target in targets.slice(0, 1 + get_multishot()):
			_fire(target)


## Living enemies in reach, furthest along the path first.
func _targets_in_range() -> Array[Enemy]:
	var reach := get_range()
	var found: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= reach:
			found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.progress > b.progress)
	return found


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
