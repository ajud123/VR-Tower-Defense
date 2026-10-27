extends StaticBody3D
## A tower for sale on the shop tray. Click it (or point + trigger) to pick
## it and then click a tile, or in VR grab it with the grip and drop it on a
## tile. The shop never runs out.
##
## A price tag in front of it shows the name and price. While a hand or
## pointer is on it, it lifts and a ring lights up under it.

const HOVER_LIFT := 0.02
const PICKED_COLOR := Color(1.0, 0.85, 0.3)
const HOVER_COLOR := Color(0.5, 0.95, 1.0)
const PRICE_COLOR := Color(0.15, 0.12, 0.1)
const TOO_EXPENSIVE_COLOR := Color(0.85, 0.15, 0.1)
const TAG_COLOR := Color(0.96, 0.92, 0.8)
## Where the tag sits, leaning back towards the player.
const TAG_POSITION := Vector3(-0.085, 0.012, 0.0)
const TAG_ROTATION := Vector3(-55.0, -60.0, 0.0)

@export var tower_scene: PackedScene
@export var placer: TowerPlacer

var _display: Tower
var _hover_count: int = 0
var _price_label: Label3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D


func _ready() -> void:
	_display = tower_scene.instantiate()
	_display.make_preview(false)
	_display.upgrades = placer.game.upgrades
	add_child(_display)
	_build_tag()
	_build_ring()


func _process(_delta: float) -> void:
	# Cards and towers already built change the price, so keep the tag current.
	var cost := placer.price_of(_display)
	_price_label.text = str(cost)
	_price_label.modulate = PRICE_COLOR if placer.game.can_afford(cost) else TOO_EXPENSIVE_COLOR
	var picked := is_picked()
	var lit := picked or is_hovered()
	_display.position.y = HOVER_LIFT if lit else 0.0
	_ring.visible = lit
	_ring_material.albedo_color = PICKED_COLOR if picked else HOVER_COLOR


func is_hovered() -> bool:
	return _hover_count > 0


func is_picked() -> bool:
	return placer.selected == tower_scene


func get_tower() -> Tower:
	return _display


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	placer.select(tower_scene)


## VR grab: hands the hand the placer, which carries the tower until release().
func grab(hand: Node3D) -> Object:
	return placer if placer.begin_carry(tower_scene, hand) else null


func hover_enter() -> void:
	_hover_count += 1


func hover_exit() -> void:
	_hover_count = maxi(_hover_count - 1, 0)


func _build_tag() -> void:
	var tag := Node3D.new()
	tag.position = TAG_POSITION
	tag.rotation_degrees = TAG_ROTATION
	add_child(tag)

	var card := BoxMesh.new()
	card.size = Vector3(0.08, 0.045, 0.003)
	var material := StandardMaterial3D.new()
	material.albedo_color = TAG_COLOR
	card.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = card
	tag.add_child(mesh)

	tag.add_child(_tag_label(_display.display_name.to_upper(), 26, Vector3(0, 0.012, 0.002)))
	var coin := Icons.sprite("gold", 0.02, Color(0.85, 0.65, 0.1))
	coin.position = Vector3(-0.018, -0.008, 0.002)
	tag.add_child(coin)
	_price_label = _tag_label("", 38, Vector3(0.012, -0.008, 0.002))
	tag.add_child(_price_label)


func _tag_label(text: String, font_size: int, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0005
	label.outline_size = 0
	label.modulate = PRICE_COLOR
	label.position = at
	return label


func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.05
	torus.outer_radius = 0.058
	torus.rings = 32
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = _ring_material
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.scale.y = 0.2
	_ring.position.y = 0.003
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
