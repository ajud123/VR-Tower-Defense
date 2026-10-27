class_name Effects
## Small particle effects sized for the tabletop (sizes in metres): bursts
## on hits and deaths, trails behind shots, a flash ring for splash damage.
## Everything here cleans itself up.

## A one-off puff of particles at `at`, e.g. an explosion or a death.
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 16,
		size: float = 0.006, speed: float = 0.12, lifetime: float = 0.45) -> void:
	var particles := _particles(color, size, lifetime)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -0.25, 0)
	_fire_once(parent, particles, at)


## A stream of particles left behind something moving. Add it as a child of
## the moving thing; call stop_trail() when it's done.
static func trail(color: Color, size: float = 0.004, lifetime: float = 0.25) -> CPUParticles3D:
	var particles := _particles(color, size, lifetime)
	particles.amount = 24
	particles.local_coords = false
	particles.spread = 180.0
	particles.initial_velocity_max = 0.01
	particles.gravity = Vector3(0, 0.02, 0)
	return particles


## Leaves a trail where it is so its last particles fade out naturally,
## instead of vanishing with the thing it followed.
static func stop_trail(particles: CPUParticles3D) -> void:
	if not is_instance_valid(particles):
		return
	var world_transform := particles.global_transform
	var scene := particles.get_tree().current_scene
	particles.get_parent().remove_child(particles)
	scene.add_child(particles)
	particles.global_transform = world_transform
	particles.emitting = false
	_free_after(particles, particles.lifetime + 0.1)


## A small, quick pop for a splash hit `radius` metres across: a little
## fireball, a few flames and sparks, a wisp of smoke. Kept modest on purpose:
## it should mark the hit, not pull the player's eye off the board.
static func explosion(parent: Node, at: Vector3, radius: float) -> void:
	# Fireball.
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hot.albedo_color = Color(1.0, 0.7, 0.2, 0.7)
	ball.material = hot
	var fireball := MeshInstance3D.new()
	fireball.mesh = ball
	fireball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fireball)
	fireball.global_position = at + Vector3.UP * radius * 0.15
	fireball.scale = Vector3.ONE * radius * 0.1
	var tween := fireball.create_tween().set_parallel()
	tween.tween_property(fireball, "scale", Vector3.ONE * radius * 0.25, 0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(hot, "albedo_color", Color(0.9, 0.25, 0.05, 0.0), 0.15)
	tween.chain().tween_callback(fireball.queue_free)

	# Flames, sparks and smoke.
	var flames := _particles(Color.WHITE, radius * 0.22, 0.3)
	flames.color_ramp = _ramp([Color(1, 0.85, 0.4), Color(1, 0.45, 0.05), Color(0.6, 0.1, 0.02, 0)])
	_explode_particles(parent, flames, at, 8, radius * 1.8, Vector3(0, 0.1, 0), 70.0)
	var sparks := _particles(Color.WHITE, radius * 0.06, 0.3)
	sparks.color_ramp = _ramp([Color(1, 1, 0.7), Color(1, 0.6, 0.2, 0)])
	_explode_particles(parent, sparks, at, 6, radius * 4.0, Vector3(0, -0.6, 0), 70.0)
	var smoke := _particles(Color.WHITE, radius * 0.3, 0.6)
	smoke.color_ramp = _ramp([Color(0.35, 0.33, 0.32, 0.5), Color(0.5, 0.5, 0.5, 0)])
	_explode_particles(parent, smoke, at, 4, radius * 0.8, Vector3(0, 0.15, 0), 50.0)


## Something heavy landing hard (a boulder): no fire, just a cloud of dust
## rolling outwards and chips of rock flying up and falling back.
static func impact(parent: Node, at: Vector3, radius: float) -> void:
	var dust := _particles(Color.WHITE, radius * 0.45, 0.9)
	dust.color_ramp = _ramp([Color(0.72, 0.62, 0.5, 0.85), Color(0.8, 0.74, 0.65, 0)])
	_explode_particles(parent, dust, at, 18, radius * 2.5, Vector3(0, 0.05, 0), 85.0)
	var rocks := _particles(Color.WHITE, radius * 0.12, 0.6)
	rocks.color_ramp = _ramp([Color(0.45, 0.42, 0.4), Color(0.45, 0.42, 0.4, 0)])
	_explode_particles(parent, rocks, at, 12, radius * 5.0, Vector3(0, -1.2, 0), 50.0)
	# Rocks fall back down instead of slowing to a stop like the dust.
	rocks.damping_min = 0.0
	rocks.damping_max = 0.0


## Fires a one-shot burst upwards from just above `at` (so none of it
## disappears into the ground), within `spread` degrees of straight up.
static func _explode_particles(parent: Node, particles: CPUParticles3D, at: Vector3,
		amount: int, speed: float, gravity: Vector3, spread: float) -> void:
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.direction = Vector3.UP
	particles.spread = spread
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 2.0
	particles.damping_max = speed * 3.0
	particles.gravity = gravity
	_fire_once(parent, particles, at + Vector3.UP * 0.01)


## Places a one-shot emitter at `at` and starts it. One-shot emitters work in
## local coordinates: in world coordinates their first (and only) burst comes
## out where the node was before it was moved, i.e. under the table.
static func _fire_once(parent: Node, particles: CPUParticles3D, at: Vector3) -> void:
	particles.local_coords = true
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	_free_after(particles, particles.lifetime + 0.1)


static func _ramp(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient


## A quick glowing bolt from `from` to `to`, e.g. chain lightning.
static func zap(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.001:
		return
	var bolt := BoxMesh.new()
	bolt.size = Vector3(0.003, 0.003, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	bolt.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = bolt
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = (from + to) * 0.5
	mesh.look_at(to, Vector3.UP if absf(from.direction_to(to).y) < 0.99 else Vector3.RIGHT)
	burst(parent, to, color, 8, 0.005, 0.08, 0.25)
	var tween := mesh.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(mesh.queue_free)


## A flat ring that grows to `radius` and fades, e.g. to show a splash.
static func ring(parent: Node, at: Vector3, radius: float, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	torus.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at
	mesh.scale = Vector3(radius * 0.3, 0.02, radius * 0.3)
	var tween := mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3(radius, 0.02, radius), 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(mesh.queue_free)


static func _particles(color: Color, size: float, lifetime: float) -> CPUParticles3D:
	# Tiny low-poly balls: round from every side, so no billboarding needed.
	var puff := SphereMesh.new()
	puff.radius = size * 0.5
	puff.height = size
	puff.radial_segments = 6
	puff.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	# Particle colours are given in sRGB, like everything else here.
	material.vertex_color_is_srgb = true
	puff.material = material
	var particles := CPUParticles3D.new()
	particles.mesh = puff
	particles.lifetime = lifetime
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.3))
	particles.scale_amount_curve = shrink
	return particles


static func _free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
