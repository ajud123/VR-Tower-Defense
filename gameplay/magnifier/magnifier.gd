class_name Magnifier
extends StaticBody3D
## The magnifying glass: focus sunlight through the lens to scorch enemies.
##
## How it works:
## - In VR: grab the handle with the grip. When the lens is angled towards the
##   sun in the sky, it focuses sunlight into a concentrated beam that shines
##   in the direction of the sun's rays—directly into the magnifier's shadow.
## - Focusing the beam onto enemies deals continuous fire damage and ignites
##   them with burning damage over time.
## - Releasing the grip returns the magnifier smoothly to the picnic table.
## - On Desktop: click to pick it up; aiming at the board automatically hovers
##   the magnifier focused on the crosshair. Right-click returns it to the table.

const PICKABLE_LAYERS := 10
const WORLD_LAYER := 1
const RETURN_TIME := 0.4

## VR hand offset: resting comfortably in the palm, lens tilted up and forward
## to naturally catch sunlight when holding the controller.
const HAND_OFFSET := Transform3D(Basis(Vector3.RIGHT, -PI * 0.35), Vector3(0, 0.03, -0.05))
const DESKTOP_OFFSET := Transform3D(Basis(Vector3.RIGHT, -PI * 0.25), Vector3(0, -0.04, -0.08))

## Distance settings: player must bring their hand close to the target (~14 cm) to focus the light.
const FOCAL_DISTANCE := 0.14
const FOCAL_TOLERANCE := 0.07

## Angle settings: lens must genuinely face the sun (tight margins, within ~35 degrees).
const MIN_ALIGNMENT := 0.78
const FULL_ALIGNMENT := 0.94

## Burn settings (tuned as a last-resort tool, not a substitute for towers).
const BURN_RADIUS := 0.035
const MAX_DPS := 1.6
const IGNITE_DURATION := 1.0

## Colors.
const BEAM_COLOR := Color(1.0, 0.94, 0.75)
const BURN_SPOT_COLOR := Color(1.0, 0.9, 0.4)
const SPARK_COLOR := Color(1.0, 0.65, 0.15)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.3)

@export var sun: DirectionalLight3D

@onready var _handle: MeshInstance3D = $Handle
@onready var _lens: MeshInstance3D = $Lens
@onready var _frame: MeshInstance3D = $Frame
@onready var _spot_light: SpotLight3D = $SpotLight3D

var _holder: Node3D
var _hold_offset: Transform3D
var _rest: Transform3D
var _return_tween: Tween
var _hover_count: int = 0
var _focus: float = 0.0

var _burn_spot: MeshInstance3D
var _burn_particles: CPUParticles3D
var _frame_mat: StandardMaterial3D


func _ready() -> void:
	_rest = global_transform
	collision_layer = PICKABLE_LAYERS
	_find_sun()
	_setup_materials()
	_setup_spotlight()
	_setup_visuals()


func _process(delta: float) -> void:
	if _holder == null:
		_set_beam_active(false)
		return
	if not is_instance_valid(_holder):
		_go_home()
		return
	_update_held_position(delta)
	_update_optics(delta)


# VR grip grab.
func grab(hand: Node3D) -> Object:
	return self if pick_up(hand, HAND_OFFSET) else null


# VR grip release.
func release() -> void:
	_go_home()


## Pick up by either VR hand or desktop player.
func pick_up(holder: Node3D, offset: Transform3D = HAND_OFFSET) -> bool:
	if _holder:
		return false
	if _return_tween:
		_return_tween.kill()
	_holder = holder
	_hold_offset = offset
	collision_layer = 0
	return true


## Desktop right-click drop.
func drop(_at: Vector3 = Vector3.ZERO, _velocity: Vector3 = Vector3.ZERO) -> void:
	_go_home()


## Desktop click while held keeps the tool active.
func use_along(_from: Vector3, _to: Vector3) -> bool:
	return true


## Allows interaction rays to target the magnifier.
func interact(_point: Vector3 = Vector3.ZERO) -> void:
	pass


func hover_enter() -> void:
	_hover_count += 1
	_update_hover()


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	_update_hover()


func _update_hover() -> void:
	if _frame_mat:
		_frame_mat.emission_enabled = _hover_count > 0
		_frame_mat.emission = HIGHLIGHT_COLOR
		_frame_mat.emission_energy_multiplier = 0.35 if _hover_count > 0 else 0.0


func _find_sun() -> void:
	if sun:
		return
	sun = get_node_or_null("../../Sun") as DirectionalLight3D
	if sun:
		return
	for node in get_tree().get_nodes_in_group("sun"):
		if node is DirectionalLight3D:
			sun = node
			return
	sun = get_tree().root.find_child("Sun", true, false) as DirectionalLight3D


func _setup_materials() -> void:
	# Ensure the lens does not cast a shadow so light passes through inside the frame shadow.
	if _lens:
		_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Duplicate frame material for hover emission.
	if _frame and _frame.mesh and _frame.mesh.material:
		_frame_mat = _frame.mesh.material.duplicate() as StandardMaterial3D
		_frame.material_override = _frame_mat


func _setup_spotlight() -> void:
	if _spot_light:
		_spot_light.light_color = BEAM_COLOR
		_spot_light.spot_range = 1.5
		_spot_light.spot_attenuation = 1.0
		_spot_light.spot_angle = 18.0
		_spot_light.light_energy = 0.0
		_spot_light.shadow_enabled = false
		_spot_light.visible = false


func _setup_visuals() -> void:
	# Hot burning spot on the surface.
	var disc := CylinderMesh.new()
	disc.top_radius = 0.015
	disc.bottom_radius = 0.015
	disc.height = 0.001
	disc.radial_segments = 16
	var spot_mat := StandardMaterial3D.new()
	spot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spot_mat.albedo_color = BURN_SPOT_COLOR
	spot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material = spot_mat
	_burn_spot = MeshInstance3D.new()
	_burn_spot.mesh = disc
	_burn_spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burn_spot.top_level = true
	_burn_spot.visible = false
	add_child(_burn_spot)

	# Sizzling sparks and smoke at focal point.
	_burn_particles = CPUParticles3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.003
	puff.height = 0.006
	var part_mat := StandardMaterial3D.new()
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.albedo_color = SPARK_COLOR
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = part_mat
	_burn_particles.mesh = puff
	_burn_particles.lifetime = 0.35
	_burn_particles.amount = 12
	_burn_particles.explosiveness = 0.1
	_burn_particles.direction = Vector3.UP
	_burn_particles.spread = 70.0
	_burn_particles.initial_velocity_min = 0.04
	_burn_particles.initial_velocity_max = 0.12
	_burn_particles.gravity = Vector3(0, 0.08, 0)
	_burn_particles.emitting = false
	_burn_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burn_particles.top_level = true
	add_child(_burn_particles)


func _update_held_position(delta: float) -> void:
	# Detect if held by desktop player hold point.
	var is_desktop := _holder.name == "HoldPoint" or _holder.get_parent() is Camera3D
	if not is_desktop:
		global_transform = _holder.global_transform * _hold_offset
		return

	# Desktop mode: check if aiming at the table or board.
	var cam := (_holder.get_parent() as Camera3D) if _holder.get_parent() is Camera3D else null
	if cam:
		var space := get_world_3d().direct_space_state
		var from := cam.global_position
		var to := from - cam.global_basis.z * 4.0
		var ray := PhysicsRayQueryParameters3D.create(from, to, 0b11)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(from) < 3.5:
			# Hover above the hit point, angled towards the sun so it automatically focuses.
			var sun_dir := _sun_direction()
			var target_lens_pos: Vector3 = hit.position - sun_dir * FOCAL_DISTANCE
			# Orient so local +Z (lens face) points towards the sun (-sun_dir).
			# In Godot, Basis.looking_at(target_dir, up) sets local -Z = target_dir, so +Z = -target_dir.
			var look_dir := sun_dir
			var up_vec := Vector3.UP if absf(look_dir.y) < 0.99 else Vector3.FORWARD
			var target_basis := Basis.looking_at(look_dir, up_vec)
			var target_pos := target_lens_pos - target_basis * Vector3(0, 0.116, 0)
			global_position = global_position.lerp(target_pos, minf(delta * 16.0, 1.0))
			global_basis = global_basis.slerp(target_basis, minf(delta * 16.0, 1.0))
			return

	var fallback_target: Transform3D = _holder.global_transform * DESKTOP_OFFSET
	global_position = global_position.lerp(fallback_target.origin, minf(delta * 10.0, 1.0))
	global_basis = global_basis.slerp(fallback_target.basis, minf(delta * 10.0, 1.0))


func _update_optics(delta: float) -> void:
	var sun_dir := _sun_direction()
	var lens_pos := _lens.global_position
	# The lens normal passing through the glass in world space is Magnifier's local Z.
	var lens_normal := global_basis.z.normalized()
	var alignment := absf(lens_normal.dot(sun_dir))

	var space := get_world_3d().direct_space_state

	# Cast along the sun ray to find where the beam hits the world.
	var beam_ray := PhysicsRayQueryParameters3D.create(lens_pos, lens_pos + sun_dir * 3.0, 0b11)
	var beam_hit := space.intersect_ray(beam_ray)
	var hit_point: Vector3
	var hit_dist: float
	var has_hit := false
	if not beam_hit.is_empty():
		hit_point = beam_hit.position
		hit_dist = lens_pos.distance_to(hit_point)
		has_hit = true
	elif lens_pos.y > 0.7835 and absf(sun_dir.y) > 0.01:
		# Fallback to the table/board surface if ray missed a physics edge.
		var t_surface := (0.7835 - lens_pos.y) / sun_dir.y
		if t_surface > 0.0:
			hit_dist = t_surface
			hit_point = lens_pos + sun_dir * t_surface
			has_hit = true
	else:
		hit_dist = 1.0
		hit_point = lens_pos + sun_dir * hit_dist

	# Calculate focus quality based on angle to sun and distance to surface.
	var angle_factor := clampf((alignment - MIN_ALIGNMENT) / (FULL_ALIGNMENT - MIN_ALIGNMENT), 0.0, 1.0)
	var dist_factor := clampf(1.0 - absf(hit_dist - FOCAL_DISTANCE) / FOCAL_TOLERANCE, 0.0, 1.0)
	# Pure multiplicative: both angle and proximity are strictly required to focus.
	var target_focus := angle_factor * dist_factor
	_focus = move_toward(_focus, target_focus, delta * 5.0)

	# Update the spotlight shining in the sun's direction into the magnifier's shadow.
	if _spot_light:
		if _focus > 0.05:
			_spot_light.visible = true
			_spot_light.global_position = lens_pos
			_spot_light.look_at(lens_pos + sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
			_spot_light.light_energy = lerpf(0.4, 5.0, _focus)
			_spot_light.spot_angle = lerpf(18.0, 5.0, _focus)
			_spot_light.spot_range = maxf(hit_dist + 0.2, 0.4)
		else:
			_spot_light.visible = false

	# Update visual focal spot on the surface (contracts to a tight pinpoint as focus sharpens).
	if _focus > 0.15 and has_hit:
		_burn_spot.visible = true
		_burn_spot.global_position = hit_point + Vector3.UP * 0.002
		var spot_scale := lerpf(1.2, 0.35, _focus)
		_burn_spot.scale = Vector3(spot_scale, 1.0, spot_scale)
	else:
		_burn_spot.visible = false

	# Burn enemies near the beam (single-target: focuses on the closest enemy).
	var burning_enemy := false
	if _focus >= 0.35:
		var dps := MAX_DPS * _focus
		var target_enemy: Enemy = null
		var closest_dist := BURN_RADIUS
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.is_dead():
				continue
			var enemy_center := enemy.global_position + Vector3.UP * 0.02
			var to_enemy := enemy_center - lens_pos
			var proj := to_enemy.dot(sun_dir)
			if proj < 0.0 or proj > hit_dist + 0.08:
				continue
			var closest := lens_pos + sun_dir * proj
			var dist := enemy_center.distance_to(closest)
			if dist < closest_dist:
				closest_dist = dist
				target_enemy = enemy
		if target_enemy:
			burning_enemy = true
			target_enemy.take_damage(dps * delta)
			target_enemy.ignite(dps * 0.5, IGNITE_DURATION)

	# Sparks and smoke particles at focal point.
	if _burn_particles:
		if _focus >= 0.35 and has_hit:
			_burn_particles.global_position = hit_point
			_burn_particles.emitting = true
		else:
			_burn_particles.emitting = false

	# VR controller haptics.
	if burning_enemy and _holder and _holder.has_method("pulse"):
		_holder.pulse(0.12 * _focus, 0.04)


func _set_beam_active(active: bool) -> void:
	_focus = 0.0
	if _spot_light:
		_spot_light.visible = active
	if _burn_spot:
		_burn_spot.visible = active
	if _burn_particles:
		_burn_particles.emitting = false


func _go_home() -> void:
	_holder = null
	_set_beam_active(false)
	if _return_tween:
		_return_tween.kill()
	_return_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_return_tween.tween_property(self, "global_transform", _rest, RETURN_TIME)
	_return_tween.tween_callback(func() -> void: collision_layer = PICKABLE_LAYERS)


func _sun_direction() -> Vector3:
	if is_instance_valid(sun):
		return -sun.global_basis.z.normalized()
	return Vector3(-0.3249, -0.7833, -0.5299).normalized()
