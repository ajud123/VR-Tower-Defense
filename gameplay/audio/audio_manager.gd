extends Node
## Central audio manager (autoloaded as `Audio`).
## Provides pooled spatial 3D and 2D playback with per-sound cooldown throttling
## and subtle pitch jitter so miniature tabletop combat stays crisp and cozy
## without ever clipping or fatiguing the player.

const POOL_3D_SIZE := 28
const POOL_2D_SIZE := 8

## Sound registry:
##   path        - res:// path to audio stream
##   bus         - AudioServer bus name ("Combat", "SFX", "Ambience", "Music")
##   volume_db   - base gain in dB
##   pitch_var   - random +/- pitch variation
##   cooldown_ms - minimum milliseconds between plays of the same sound ID
##   unit_size   - 3D reference distance in metres (tighter = smaller/fainter)
##   max_dist    - 3D max audible distance in metres
const SOUNDS := {
	# --- Miniature Tabletop Combat (intentionally delicate & tightly attenuated) ---
	"archer_shoot": {
		"path": "res://assets/audio/combat/archer_shoot.ogg",
		"bus": "Combat", "volume_db": -14.0, "pitch_var": 0.12, "cooldown_ms": 75,
		"unit_size": 0.28, "max_dist": 2.6,
	},
	"cannon_shoot": {
		"path": "res://assets/audio/combat/cannon_shoot.ogg",
		"bus": "Combat", "volume_db": -10.5, "pitch_var": 0.08, "cooldown_ms": 110,
		"unit_size": 0.35, "max_dist": 3.0,
	},
	"mage_shoot": {
		"path": "res://assets/audio/combat/mage_shoot.ogg",
		"bus": "Combat", "volume_db": -13.0, "pitch_var": 0.1, "cooldown_ms": 85,
		"unit_size": 0.3, "max_dist": 2.8,
	},
	"catapult_shoot": {
		"path": "res://assets/audio/combat/catapult_shoot.ogg",
		"bus": "Combat", "volume_db": -11.0, "pitch_var": 0.08, "cooldown_ms": 140,
		"unit_size": 0.35, "max_dist": 3.0,
	},
	"impact_explosion": {
		"path": "res://assets/audio/combat/impact_explosion.ogg",
		"bus": "Combat", "volume_db": -11.0, "pitch_var": 0.1, "cooldown_ms": 95,
		"unit_size": 0.35, "max_dist": 3.0,
	},
	"impact_boulder": {
		"path": "res://assets/audio/combat/impact_boulder.ogg",
		"bus": "Combat", "volume_db": -10.5, "pitch_var": 0.1, "cooldown_ms": 100,
		"unit_size": 0.35, "max_dist": 3.0,
	},
	"impact_cluster": {
		"path": "res://assets/audio/combat/impact_cluster.ogg",
		"bus": "Combat", "volume_db": -15.0, "pitch_var": 0.14, "cooldown_ms": 60,
		"unit_size": 0.25, "max_dist": 2.4,
	},
	"proc_chain": {
		"path": "res://assets/audio/combat/proc_chain.ogg",
		"bus": "Combat", "volume_db": -14.0, "pitch_var": 0.12, "cooldown_ms": 85,
		"unit_size": 0.3, "max_dist": 2.6,
	},
	"proc_frost": {
		"path": "res://assets/audio/combat/proc_frost.ogg",
		"bus": "Combat", "volume_db": -15.0, "pitch_var": 0.1, "cooldown_ms": 130,
		"unit_size": 0.28, "max_dist": 2.6,
	},
	"enemy_death": {
		"path": "res://assets/audio/combat/enemy_death.ogg",
		"bus": "Combat", "volume_db": -14.0, "pitch_var": 0.14, "cooldown_ms": 80,
		"unit_size": 0.28, "max_dist": 2.6,
	},
	"enemy_death_skeleton": {
		"path": "res://assets/audio/combat/enemy_death_skeleton.ogg",
		"bus": "Combat", "volume_db": -13.0, "pitch_var": 0.12, "cooldown_ms": 90,
		"unit_size": 0.3, "max_dist": 2.8,
	},
	"enemy_death_ghost": {
		"path": "res://assets/audio/combat/enemy_death_ghost.ogg",
		"bus": "Combat", "volume_db": -14.0, "pitch_var": 0.1, "cooldown_ms": 90,
		"unit_size": 0.3, "max_dist": 2.8,
	},
	"enemy_death_boss": {
		"path": "res://assets/audio/combat/enemy_death_boss.ogg",
		"bus": "SFX", "volume_db": -6.0, "pitch_var": 0.04, "cooldown_ms": 200,
		"unit_size": 0.8, "max_dist": 6.0,
	},
	"castle_hit": {
		"path": "res://assets/audio/combat/castle_hit.ogg",
		"bus": "SFX", "volume_db": -4.0, "pitch_var": 0.05, "cooldown_ms": 160,
		"unit_size": 0.9, "max_dist": 6.0,
	},

	# --- Tactile Tabletop Toys & VR Interactions ---
	"tower_build": {
		"path": "res://assets/audio/toys/tower_build.ogg",
		"bus": "SFX", "volume_db": -4.0, "pitch_var": 0.08, "cooldown_ms": 60,
		"unit_size": 0.7, "max_dist": 5.0,
	},
	"tower_upgrade": {
		"path": "res://assets/audio/toys/tower_upgrade.ogg",
		"bus": "SFX", "volume_db": -5.0, "pitch_var": 0.04, "cooldown_ms": 80,
		"unit_size": 0.8, "max_dist": 5.0,
	},
	"tower_upgrade_max": {
		"path": "res://assets/audio/toys/tower_upgrade_max.ogg",
		"bus": "SFX", "volume_db": -4.5, "pitch_var": 0.02, "cooldown_ms": 80,
		"unit_size": 0.9, "max_dist": 6.0,
	},
	"action_error": {
		"path": "res://assets/audio/toys/action_error.ogg",
		"bus": "SFX", "volume_db": -7.0, "pitch_var": 0.04, "cooldown_ms": 140,
		"unit_size": 0.8, "max_dist": 6.0,
	},
	"hammer_smash": {
		"path": "res://assets/audio/toys/hammer_smash.ogg",
		"bus": "SFX", "volume_db": -3.0, "pitch_var": 0.08, "cooldown_ms": 100,
		"unit_size": 0.85, "max_dist": 6.0,
	},
	"coins": {
		"path": "res://assets/audio/toys/coins.ogg",
		"bus": "SFX", "volume_db": -5.5, "pitch_var": 0.07, "cooldown_ms": 100,
		"unit_size": 0.9, "max_dist": 8.0,
	},
	"card_pickup": {
		"path": "res://assets/audio/toys/card_pickup.ogg",
		"bus": "SFX", "volume_db": -5.0, "pitch_var": 0.08, "cooldown_ms": 50,
		"unit_size": 0.6, "max_dist": 4.0,
	},
	"card_drop": {
		"path": "res://assets/audio/toys/card_drop.ogg",
		"bus": "SFX", "volume_db": -6.0, "pitch_var": 0.08, "cooldown_ms": 50,
		"unit_size": 0.6, "max_dist": 4.0,
	},
	"card_equip": {
		"path": "res://assets/audio/toys/card_equip.ogg",
		"bus": "SFX", "volume_db": -5.0, "pitch_var": 0.04, "cooldown_ms": 70,
		"unit_size": 0.7, "max_dist": 5.0,
	},
	"card_store": {
		"path": "res://assets/audio/toys/card_store.ogg",
		"bus": "SFX", "volume_db": -7.0, "pitch_var": 0.08, "cooldown_ms": 60,
		"unit_size": 0.6, "max_dist": 4.0,
	},
	"button_press": {
		"path": "res://assets/audio/toys/button_press.ogg",
		"bus": "SFX", "volume_db": -5.0, "pitch_var": 0.05, "cooldown_ms": 70,
		"unit_size": 0.7, "max_dist": 5.0,
	},
	"hover_tick": {
		"path": "res://assets/audio/toys/hover_tick.ogg",
		"bus": "SFX", "volume_db": -16.0, "pitch_var": 0.06, "cooldown_ms": 50,
		"unit_size": 0.5, "max_dist": 3.0,
	},
	"lever_clunk": {
		"path": "res://assets/audio/toys/lever_clunk.ogg",
		"bus": "SFX", "volume_db": -3.0, "pitch_var": 0.05, "cooldown_ms": 120,
		"unit_size": 1.3, "max_dist": 10.0,
	},
	"lever_spring": {
		"path": "res://assets/audio/toys/lever_spring.ogg",
		"bus": "SFX", "volume_db": -6.5, "pitch_var": 0.06, "cooldown_ms": 150,
		"unit_size": 1.2, "max_dist": 9.0,
	},
	"radio_click": {
		"path": "res://assets/audio/toys/radio_click.ogg",
		"bus": "SFX", "volume_db": -5.0, "pitch_var": 0.05, "cooldown_ms": 80,
		"unit_size": 0.6, "max_dist": 4.0,
	},

	# --- Behind-the-Bench Machines (wider spatial reach so player hears them behind the bench) ---
	"vending_unlock": {
		"path": "res://assets/audio/machines/vending_unlock.ogg",
		"bus": "SFX", "volume_db": -1.5, "pitch_var": 0.0, "cooldown_ms": 500,
		"unit_size": 2.4, "max_dist": 16.0,
	},
	"vending_dispense": {
		"path": "res://assets/audio/machines/vending_dispense.ogg",
		"bus": "SFX", "volume_db": -2.5, "pitch_var": 0.05, "cooldown_ms": 150,
		"unit_size": 1.6, "max_dist": 12.0,
	},
	"rarity_common": {
		"path": "res://assets/audio/machines/rarity_common.ogg",
		"bus": "SFX", "volume_db": -4.0, "pitch_var": 0.02, "cooldown_ms": 100,
		"unit_size": 1.8, "max_dist": 12.0,
	},
	"rarity_rare": {
		"path": "res://assets/audio/machines/rarity_rare.ogg",
		"bus": "SFX", "volume_db": -3.0, "pitch_var": 0.02, "cooldown_ms": 100,
		"unit_size": 2.0, "max_dist": 14.0,
	},
	"rarity_epic": {
		"path": "res://assets/audio/machines/rarity_epic.ogg",
		"bus": "SFX", "volume_db": -1.5, "pitch_var": 0.0, "cooldown_ms": 100,
		"unit_size": 2.4, "max_dist": 16.0,
	},

	# --- Park Spatial Birds ---
	"bird_chirp_1": {
		"path": "res://assets/audio/ambience/bird_chirp_1.ogg",
		"bus": "Ambience", "volume_db": -8.0, "pitch_var": 0.12, "cooldown_ms": 400,
		"unit_size": 3.5, "max_dist": 25.0,
	},
	"bird_chirp_2": {
		"path": "res://assets/audio/ambience/bird_chirp_2.ogg",
		"bus": "Ambience", "volume_db": -8.0, "pitch_var": 0.12, "cooldown_ms": 400,
		"unit_size": 3.5, "max_dist": 25.0,
	},
	"bird_chirp_3": {
		"path": "res://assets/audio/ambience/bird_chirp_3.ogg",
		"bus": "Ambience", "volume_db": -9.0, "pitch_var": 0.08, "cooldown_ms": 600,
		"unit_size": 3.5, "max_dist": 25.0,
	},

	# --- Wave & Game State Cues (2D) ---
	"countdown_tick": {
		"path": "res://assets/audio/waves/countdown_tick.ogg",
		"bus": "SFX", "volume_db": -12.0, "pitch_var": 0.0, "cooldown_ms": 200,
	},
	"wave_start": {
		"path": "res://assets/audio/waves/wave_start.ogg",
		"bus": "SFX", "volume_db": -8.0, "pitch_var": 0.02, "cooldown_ms": 500,
	},
	"wave_boss": {
		"path": "res://assets/audio/waves/wave_boss.ogg",
		"bus": "SFX", "volume_db": -12.5, "pitch_var": 0.0, "cooldown_ms": 500,
	},
	"wave_clear": {
		"path": "res://assets/audio/waves/wave_clear.ogg",
		"bus": "SFX", "volume_db": -6.5, "pitch_var": 0.02, "cooldown_ms": 500,
	},
	"game_win": {
		"path": "res://assets/audio/waves/game_win.ogg",
		"bus": "SFX", "volume_db": -4.0, "pitch_var": 0.0, "cooldown_ms": 500,
	},
	"game_over": {
		"path": "res://assets/audio/waves/game_over.ogg",
		"bus": "SFX", "volume_db": -4.5, "pitch_var": 0.0, "cooldown_ms": 500,
	},
}

var _streams: Dictionary = {}  # String -> AudioStream
var _last_played: Dictionary = {}  # String -> int (ticks_msec)
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _cursor_3d: int = 0
var _cursor_2d: int = 0


func _ready() -> void:
	for id: String in SOUNDS:
		var path: String = SOUNDS[id].path
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for i in POOL_3D_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_polyphony = 1
		add_child(player)
		_pool_3d.append(player)
	for i in POOL_2D_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool_2d.append(player)


## Plays a registered sound spatially at `world_position`.
func play_3d(id: String, world_position: Vector3, volume_offset_db: float = 0.0, pitch_override: float = -1.0) -> void:
	var cfg: Dictionary = SOUNDS.get(id, {})
	if cfg.is_empty() or not _streams.has(id):
		return
	if not _check_cooldown(id, cfg.get("cooldown_ms", 0)):
		return
	var player := _next_3d()
	player.stop()
	player.stream = _streams[id]
	player.bus = _safe_bus(cfg.get("bus", "SFX"))
	player.global_position = world_position
	player.volume_db = cfg.get("volume_db", 0.0) + volume_offset_db
	player.unit_size = cfg.get("unit_size", 1.0)
	player.max_distance = cfg.get("max_dist", 10.0)
	var pvar: float = cfg.get("pitch_var", 0.0)
	player.pitch_scale = pitch_override if pitch_override > 0.0 else (1.0 + randf_range(-pvar, pvar))
	player.play()


## Plays a registered non-spatial 2D sound (wave cues, victory/defeat).
func play_2d(id: String, volume_offset_db: float = 0.0, pitch_override: float = -1.0) -> void:
	var cfg: Dictionary = SOUNDS.get(id, {})
	if cfg.is_empty() or not _streams.has(id):
		return
	if not _check_cooldown(id, cfg.get("cooldown_ms", 0)):
		return
	var player := _next_2d()
	player.stop()
	player.stream = _streams[id]
	player.bus = _safe_bus(cfg.get("bus", "SFX"))
	player.volume_db = cfg.get("volume_db", 0.0) + volume_offset_db
	var pvar: float = cfg.get("pitch_var", 0.0)
	player.pitch_scale = pitch_override if pitch_override > 0.0 else (1.0 + randf_range(-pvar, pvar))
	player.play()


## Loads an audio stream and enables looping if it's an Ogg Vorbis stream.
func load_looping(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _check_cooldown(id: String, cooldown_ms: int) -> bool:
	if cooldown_ms <= 0:
		return true
	var now := Time.get_ticks_msec()
	var prev: int = _last_played.get(id, -100000)
	if now - prev < cooldown_ms:
		return false
	_last_played[id] = now
	return true


func _next_3d() -> AudioStreamPlayer3D:
	for i in POOL_3D_SIZE:
		var idx := (_cursor_3d + i) % POOL_3D_SIZE
		if not _pool_3d[idx].playing:
			_cursor_3d = (idx + 1) % POOL_3D_SIZE
			return _pool_3d[idx]
	var fallback := _pool_3d[_cursor_3d]
	_cursor_3d = (_cursor_3d + 1) % POOL_3D_SIZE
	return fallback


func _next_2d() -> AudioStreamPlayer:
	for i in POOL_2D_SIZE:
		var idx := (_cursor_2d + i) % POOL_2D_SIZE
		if not _pool_2d[idx].playing:
			_cursor_2d = (idx + 1) % POOL_2D_SIZE
			return _pool_2d[idx]
	var fallback := _pool_2d[_cursor_2d]
	_cursor_2d = (_cursor_2d + 1) % POOL_2D_SIZE
	return fallback


func _safe_bus(bus_name: String) -> StringName:
	return StringName(bus_name) if AudioServer.get_bus_index(bus_name) != -1 else &"Master"
