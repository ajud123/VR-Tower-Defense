class_name Icons
## Flat white icons (gameplay/icons/<key>.svg, from game-icons.net, see
## CREDITS.md) for cards, signs and buttons. They're white on clear, so tint
## them with modulate.
##
## Keys match card targets and stats ("archer", "tank", "fire_rate",
## "burn_dps", ...) plus a few for the UI ("gold", "wave", "restart", ...).

const DIR := "res://gameplay/icons/"

## Tints for stat icons, so e.g. burn always reads as fire.
const STAT_COLORS := {
	"damage": Color(0.95, 0.95, 0.95),
	"fire_rate": Color(1.0, 0.9, 0.4),
	"range": Color(0.55, 0.9, 1.0),
	"splash_radius": Color(1.0, 0.6, 0.25),
	"cost": Color(0.6, 1.0, 0.55),
	"burn_dps": Color(1.0, 0.5, 0.15),
	"slow": Color(0.6, 0.9, 1.0),
	"health": Color(1.0, 0.35, 0.4),
	"speed": Color(0.85, 0.75, 1.0),
	"reward": Color(1.0, 0.82, 0.25),
	"damage_taken": Color(1.0, 0.45, 0.4),
	"chain": Color(0.6, 0.85, 1.0),
	"multishot": Color(1.0, 0.9, 0.5),
	"cluster": Color(1.0, 0.6, 0.25),
	"pierce": Color(0.85, 0.88, 0.95),
	"knockback": Color(0.9, 0.7, 0.45),
	"shatter": Color(0.6, 0.9, 1.0),
	"dps": Color(1.0, 0.55, 0.45),
}


static func texture(key: String) -> Texture2D:
	var path := DIR + key + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


static func stat_color(stat: String) -> Color:
	return STAT_COLORS.get(stat, Color.WHITE)


## A flat icon `size` metres across, facing +Z.
static func sprite(key: String, size: float, color: Color = Color.WHITE) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture(key)
	if sprite.texture:
		sprite.pixel_size = size / sprite.texture.get_width()
	sprite.modulate = color
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite
