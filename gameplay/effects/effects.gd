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
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	_free_after(particles, lifetime + 0.1)


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
