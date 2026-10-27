extends Node3D
## The park lamp: the Kenney graveyard lamp post, painted metal grey. The
## pack's palette is green there, but the zombie shares that palette, so the
## lamp gets its own copy (colormap_lamp.png) instead.

const LAMP_COLORMAP := preload("res://assets/kenney/graveyard/Textures/colormap_lamp.png")


func _ready() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_texture = LAMP_COLORMAP
	metal.metallic = 0.6
	metal.roughness = 0.45
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = metal
