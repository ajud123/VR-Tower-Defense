@tool
extends Node3D
## A park tree from the Kenney nature kit, with a few bushes, rocks or
## flowers around its foot. Which tree and props it gets depends on where it
## stands, so every copy looks different but stays the same between runs.
## The kit's leaves are teal; they're shifted to the same warmer green as the
## board's grass.

const NATURE := "res://assets/kenney/nature/"
const TREES := ["tree_default", "tree_oak", "tree_fat", "tree_detailed", "tree_cone"]
const PROPS := [
	"plant_bush", "plant_bushLarge", "plant_bushDetailed", "rock_smallA",
	"rock_smallB", "rock_largeA", "flower_redA", "flower_yellowA",
	"flower_purpleA", "mushroom_redGroup", "stump_round", "grass_large",
]
## Kenney trees are under 2 m tall; park trees should tower over the bench.
const TREE_SCALE := 2.6
const PROP_SCALE := 1.6
const PROP_COUNT := 3
## Colours with a hue in this range (degrees) get turned by GREEN_SHIFT.
const TEAL_HUES := Vector2(125.0, 190.0)
const GREEN_SHIFT := -40.0

## Original material -> green copy, shared by every tree.
static var _greened: Dictionary = {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(global_position.x * 10.0), roundi(global_position.z * 10.0)))
	var tree := _add(TREES[rng.randi() % TREES.size()], Vector3.ZERO, TREE_SCALE * rng.randf_range(0.85, 1.15))
	tree.rotation.y = rng.randf() * TAU
	for i in PROP_COUNT:
		var angle := rng.randf() * TAU
		var spot := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.7, 1.5)
		var prop := _add(PROPS[rng.randi() % PROPS.size()], spot, PROP_SCALE * rng.randf_range(0.8, 1.2))
		prop.rotation.y = rng.randf() * TAU


func _add(model: String, at: Vector3, size: float) -> Node3D:
	var node: Node3D = load(NATURE + model + ".glb").instantiate()
	node.position = at
	node.scale = Vector3.ONE * size
	add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if material:
				mesh.set_surface_override_material(i, _green(material))
	return node


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
