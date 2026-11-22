@tool
extends Node3D
## Builds the cozy park details procedurally (live in editor and at runtime):
## - A smoothly winding gravel walkway with stone edging (replacing the straight slab)
## - A rounded gravel pad around the picnic table and vending/recycler patio
## - Lush pathside bushes, flowerbeds, rocks, mushrooms and an outer perimeter treeline
##   using the Kenney Nature Kit with the same warm green foliage tint as park_tree.gd.

const NATURE := "res://assets/kenney/nature/"
const TREES := ["tree_default", "tree_oak", "tree_fat", "tree_detailed", "tree_cone"]
const BUSHES := ["plant_bush", "plant_bushLarge", "plant_bushDetailed"]
const FLOWERS := ["flower_redA", "flower_yellowA", "flower_purpleA"]
const ACCENTS := ["rock_smallA", "rock_smallB", "grass_large", "mushroom_redGroup"]

const TEAL_HUES := Vector2(125.0, 190.0)
const GREEN_SHIFT := -40.0

## Control points (X, Z) for the meandering gravel walkway through the park.
const PATH_POINTS := [
	Vector2(-32.0, 7.5),
	Vector2(-22.0, 6.2),
	Vector2(-13.5, 4.7),
	Vector2(-6.0, 2.85),
	Vector2(-0.5, 3.25),
	Vector2(5.5, 2.55),
	Vector2(13.0, 3.75),
	Vector2(21.5, 2.1),
	Vector2(32.0, 0.5),
]
const PATH_HALF_WIDTH := 1.05
const CURB_WIDTH := 0.14
## Kept very close to Y=0 (strictly below the Y=0.005 ground collision plane)
## so dropped physical cards always rest cleanly on top of the path and never sink in.
const PATH_Y := 0.004
const CURB_Y := 0.0022
const PAD_Y := 0.0016

static var _greened: Dictionary = {}
static var _model_cache: Dictionary = {}

var _samples: Array[Vector2] = []
var _generated: Node3D
var _gravel_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _generated:
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "GeneratedPark"
	add_child(_generated)

	_gravel_mat = StandardMaterial3D.new()
	_gravel_mat.albedo_color = Color(0.72, 0.66, 0.56)
	_gravel_mat.roughness = 0.95

	_samples = _sample_spline(PATH_POINTS, 10)
	_build_winding_walkway()
	_build_clearings()
	_build_pathside_foliage()
	_build_perimeter_park()


func _build_winding_walkway() -> void:
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.56, 0.52, 0.45)
	curb_mat.roughness = 0.9

	# Main winding gravel ribbon.
	var gravel_mesh := _make_ribbon(_samples, -PATH_HALF_WIDTH, PATH_HALF_WIDTH, PATH_Y, _gravel_mat)
	var gravel := MeshInstance3D.new()
	gravel.name = "WindingWalkway"
	gravel.mesh = gravel_mesh
	gravel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(gravel)

	# Subtle darker stone edging strips along both sides of the path.
	for side: float in [-1.0, 1.0]:
		var inner: float = side * PATH_HALF_WIDTH
		var outer: float = side * (PATH_HALF_WIDTH + CURB_WIDTH)
		var lo: float = minf(inner, outer)
		var hi: float = maxf(inner, outer)
		var curb := MeshInstance3D.new()
		curb.mesh = _make_ribbon(_samples, lo, hi, CURB_Y, curb_mat)
		curb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_generated.add_child(curb)


## Flat gravel pads under the picnic table and the vending/recycler patio,
## stacked cleanly below PATH_Y with matching material so there is zero z-fighting.
func _build_clearings() -> void:
	# Picnic table clearing (sits cleanly beneath the bench & table).
	_add_pad(Vector3(0.0, PAD_Y, 0.0), Vector2(3.5, 2.5), _gravel_mat)
	# Smooth connector strip from the picnic pad to the walkway (distinct Y = 0.0030, strictly below PATH_Y).
	_add_pad(Vector3(0.0, 0.0030, 1.8), Vector2(1.5, 2.1), _gravel_mat)
	# Vending machine & recycler patio connecting cleanly under the walkway.
	_add_pad(Vector3(-0.55, 0.0028, 4.65), Vector2(3.1, 2.4), _gravel_mat)


func _add_pad(center: Vector3, size_xz: Vector2, mat: StandardMaterial3D) -> void:
	# Flat upward-facing disc (no thickness, so its top surface is at exact `center.y`).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var segs := 28
	var rx := size_xz.x * 0.5
	var rz := size_xz.y * 0.5
	var c := Vector3(center.x, center.y, center.z)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(center.x + cos(a0) * rx, center.y, center.z + sin(a0) * rz)
		var p1 := Vector3(center.x + cos(a1) * rx, center.y, center.z + sin(a1) * rz)
		st.set_normal(Vector3.UP)
		st.add_vertex(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(p0)
		st.set_normal(Vector3.UP)
		st.add_vertex(p1)
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(inst)


## Bushes, flowers, grass tufts and mossy rocks hugging the path curves and clearings.
func _build_pathside_foliage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42077

	# Line both sides of the winding walkway with cozy clusters.
	for i in range(4, _samples.size() - 4, 3):
		var p: Vector2 = _samples[i]
		var tang: Vector2 = (_samples[i + 1] - _samples[i - 1]).normalized()
		var norm := Vector2(-tang.y, tang.x)
		for side: float in [-1.0, 1.0]:
			if rng.randf() > 0.62:
				continue
			var dist := PATH_HALF_WIDTH + CURB_WIDTH + rng.randf_range(0.55, 1.85)
			var spot: Vector2 = p + norm * side * dist + tang * rng.randf_range(-0.4, 0.4)
			if not _is_clear(spot, 0.7):
				continue
			_place_bush_cluster(spot, rng)

	# Cozy flower & bush accents framing the picnic clearing and behind the machines.
	var garden_spots := [
		Vector2(-2.6, -1.6),
		Vector2(2.7, -1.5),
		Vector2(-2.9, 0.9),
		Vector2(2.8, 0.4),
		Vector2(-2.6, 5.4),
		Vector2(1.4, 5.7),
		Vector2(-0.6, 6.2),
		Vector2(-4.2, -3.5),
		Vector2(3.8, -3.8),
	]
	for spot in garden_spots:
		if _is_clear(spot, 0.5):
			_place_bush_cluster(spot, rng)


func _place_bush_cluster(center: Vector2, rng: RandomNumberGenerator) -> void:
	var bush_name: String = BUSHES[rng.randi() % BUSHES.size()]
	_spawn_prop(bush_name, Vector3(center.x, 0.0, center.y), rng.randf_range(1.45, 2.15), rng.randf() * TAU)

	# Add 1-2 nearby flowers or grass/rocks to make each cluster feel organic.
	var extras := rng.randi_range(1, 3)
	for _k in extras:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.45, 1.05)
		var sub := center + Vector2(cos(ang), sin(ang)) * r
		if not _is_clear(sub, 0.35):
			continue
		var pool := FLOWERS if rng.randf() < 0.6 else ACCENTS
		var prop_name: String = pool[rng.randi() % pool.size()]
		var sc := rng.randf_range(1.3, 1.9) if prop_name in FLOWERS else rng.randf_range(1.2, 1.8)
		_spawn_prop(prop_name, Vector3(sub.x, 0.0, sub.y), sc, rng.randf() * TAU)


## Soft outer perimeter of trees & bushes so the park feels nestled in nature.
func _build_perimeter_park() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91823

	# Outer treeline ring (radius 13..25 m).
	var ring_count := 26
	for i in ring_count:
		var base_ang := TAU * float(i) / float(ring_count) + rng.randf_range(-0.1, 0.1)
		var radius := rng.randf_range(13.5, 24.0)
		var spot := Vector2(cos(base_ang), sin(base_ang)) * radius
		if not _is_clear(spot, 1.8):
			continue
		var tree_name: String = TREES[rng.randi() % TREES.size()]
		var scale_val := rng.randf_range(2.3, 3.6)
		_spawn_prop(tree_name, Vector3(spot.x, 0.0, spot.y), scale_val, rng.randf() * TAU)
		# Small bush or rock at the tree's foot.
		var b_ang := rng.randf() * TAU
		var b_spot := spot + Vector2(cos(b_ang), sin(b_ang)) * rng.randf_range(0.9, 1.7)
		if _is_clear(b_spot, 0.6):
			var p_name: String = BUSHES[rng.randi() % BUSHES.size()]
			_spawn_prop(p_name, Vector3(b_spot.x, 0.0, b_spot.y), rng.randf_range(1.4, 2.2), rng.randf() * TAU)

	# Scattered mid-ground wildflower & grass patches across the park lawn.
	for _i in 32:
		var spot := Vector2(rng.randf_range(-17.0, 17.0), rng.randf_range(-14.0, 14.0))
		if not _is_clear(spot, 0.8):
			continue
		var prop_name: String = FLOWERS[rng.randi() % FLOWERS.size()] if rng.randf() < 0.65 else ACCENTS[rng.randi() % ACCENTS.size()]
		_spawn_prop(prop_name, Vector3(spot.x, 0.0, spot.y), rng.randf_range(1.3, 2.0), rng.randf() * TAU)


func _is_clear(p: Vector2, margin: float) -> bool:
	# Keep picnic clearing unobstructed.
	if absf(p.x) < 2.3 + margin and p.y > -1.4 - margin and p.y < 1.9 + margin:
		return false
	# Keep vending machine + recycler patio unobstructed.
	if p.x > -2.3 - margin and p.x < 1.3 + margin and p.y > 3.6 - margin and p.y < 5.9 + margin:
		return false
	# Keep winding walkway clear.
	var min_path_dist := PATH_HALF_WIDTH + CURB_WIDTH + margin
	var min_sq := min_path_dist * min_path_dist
	for s in _samples:
		if p.distance_squared_to(s) < min_sq:
			return false
	# Keep lamp post and existing hand-placed tree bases clear.
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is Node3D:
				if child.name.begins_with("LampPost"):
					var lp := Vector2((child as Node3D).position.x, (child as Node3D).position.z)
					if p.distance_to(lp) < 0.9 + margin * 0.4:
						return false
				elif child.name.begins_with("Tree"):
					var tp := Vector2((child as Node3D).position.x, (child as Node3D).position.z)
					if p.distance_to(tp) < 1.5 + margin * 0.5:
						return false
	return true


func _spawn_prop(model_name: String, at: Vector3, size: float, yaw: float) -> void:
	if not _model_cache.has(model_name):
		_model_cache[model_name] = load(NATURE + model_name + ".glb")
	var packed: PackedScene = _model_cache[model_name]
	if packed == null:
		return
	var node: Node3D = packed.instantiate()
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	_generated.add_child(node)
	# Only trees and bushes within shadow distance cast shadows; small flowers/grass/mushrooms skip shadow pass.
	var casts_shadow := (model_name in TREES or model_name in BUSHES) and at.length() < 22.0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not casts_shadow:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if mat:
				mesh.set_surface_override_material(i, _green(mat))


static func _green(material: StandardMaterial3D) -> StandardMaterial3D:
	if not _greened.has(material):
		var color := material.albedo_color
		var hue := color.h * 360.0
		if hue >= TEAL_HUES.x and hue <= TEAL_HUES.y and color.s > 0.2:
			var copy := material.duplicate() as StandardMaterial3D
			copy.albedo_color = Color.from_hsv(fposmod(hue + GREEN_SHIFT, 360.0) / 360.0, color.s, color.v, color.a)
			_greened[material] = copy
		else:
			_greened[material] = material
	return _greened[material]


## Catmull-Rom spline sampler for smooth curves through control points.
func _sample_spline(pts: Array, steps_per_seg: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := pts.size()
	for i in range(n - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for s in steps_per_seg:
			var t := float(s) / float(steps_per_seg)
			var t2 := t * t
			var t3 := t2 * t
			var pos := 0.5 * (
				(2.0 * p1)
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			out.append(pos)
	out.append(pts[-1])
	return out


## Builds a flat upward-facing ribbon mesh from offset `left_off` to `right_off` along `pts`.
func _make_ribbon(pts: Array[Vector2], left_off: float, right_off: float, y: float, mat: StandardMaterial3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var left_v: Array[Vector3] = []
	var right_v: Array[Vector3] = []
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tang := (next - prev).normalized()
		var norm := Vector2(-tang.y, tang.x)
		var l := pts[i] + norm * left_off
		var r := pts[i] + norm * right_off
		left_v.append(Vector3(l.x, y, l.y))
		right_v.append(Vector3(r.x, y, r.y))
	for i in range(pts.size() - 1):
		var a := left_v[i]
		var b := right_v[i]
		var c := left_v[i + 1]
		var d := right_v[i + 1]
		st.set_normal(Vector3.UP)
		st.add_vertex(a)
		st.set_normal(Vector3.UP)
		st.add_vertex(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(b)
		st.set_normal(Vector3.UP)
		st.add_vertex(b)
		st.set_normal(Vector3.UP)
		st.add_vertex(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(d)
	return st.commit()
