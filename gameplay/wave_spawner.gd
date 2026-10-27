extends Node
## Sends the scripted waves (WAVES) down the board's path. Enemies also get
## a little tougher every wave. Clearing the final wave wins the game.

## Enemy names used in WAVES.
const ENEMIES := {
	"orc": preload("res://gameplay/enemies/blob.tscn"),
	"zombie": preload("res://gameplay/enemies/tank.tscn"),
	"ghost": preload("res://gameplay/enemies/ghost.tscn"),
	"skeleton": preload("res://gameplay/enemies/skeleton.tscn"),
	"vampire": preload("res://gameplay/enemies/vampire.tscn"),
}
## Each wave has a name (shown on the status sign) and groups that come one
## after another: [enemy, count] or [enemy, count, seconds between them].
const WAVES := [
	{"name": "Scouts", "groups": [["orc", 8]]},
	{"name": "Big guys", "groups": [["orc", 8], ["zombie", 2, 1.8]]},
	{"name": "Warband", "groups": [["orc", 14, 0.8]]},
	{"name": "Ghost rush", "groups": [["orc", 6], ["ghost", 8, 0.5]]},
	{"name": "Zombie wall", "groups": [["zombie", 5, 1.6], ["orc", 8, 0.8]]},
	{"name": "Bone army", "groups": [["skeleton", 10, 0.9]]},
	{"name": "Mixed raid", "groups": [["orc", 8, 0.8], ["ghost", 6, 0.5], ["zombie", 3, 1.6]]},
	{"name": "Swarm", "groups": [["ghost", 18, 0.35]]},
	{"name": "Rattling dead", "groups": [["zombie", 4, 1.5], ["skeleton", 10, 0.8]]},
	{"name": "BOSS: The Count", "groups": [["orc", 10, 0.8], ["vampire", 1], ["skeleton", 6, 0.9]]},
	{"name": "Second wind", "groups": [["orc", 20, 0.6], ["zombie", 4, 1.4]]},
	{"name": "Haunting", "groups": [["ghost", 14, 0.4], ["skeleton", 8, 0.8]]},
	{"name": "Heavy march", "groups": [["zombie", 10, 1.3]]},
	{"name": "Ambush", "groups": [["skeleton", 10, 0.7], ["ghost", 12, 0.35]]},
	{"name": "Bone legion", "groups": [["skeleton", 22, 0.6]]},
	{"name": "Blitz", "groups": [["ghost", 30, 0.3]]},
	{"name": "The horde", "groups": [["orc", 25, 0.5], ["zombie", 8, 1.2]]},
	{"name": "Nightfall", "groups": [["zombie", 8, 1.2], ["skeleton", 12, 0.6], ["ghost", 12, 0.35]]},
	{"name": "Last stand", "groups": [["orc", 20, 0.5], ["skeleton", 15, 0.6], ["zombie", 10, 1.0]]},
	{"name": "BOSS: Vampire lords", "groups": [["skeleton", 10, 0.7], ["vampire", 2, 6.0], ["ghost", 16, 0.35]]},
]
const DEFAULT_SPACING := 1.1
## Pause between one group of a wave and the next.
const GROUP_PAUSE := 2.0

@export var board: Board
@export var game: GameState
@export var first_wave_delay: float = 15.0
@export var time_between_waves: float = 10.0
## Extra enemy health per wave after the first (0.1 = +10% each wave).
## Kept low: towers don't get stronger by themselves, only cards do.
@export var health_growth: float = 0.1
## From this wave on, health grows by late_health_growth per wave instead.
@export var late_from_wave: int = 6
@export var late_health_growth: float = 0.25
## Extra enemy speed per wave after the first.
@export var speed_growth: float = 0.03
## Gold paid for clearing a wave: base + growth * wave number.
@export var wave_clear_bonus: int = 30
@export var wave_clear_bonus_growth: int = 10

## [enemy scene, seconds to wait before spawning it] for the running wave.
var _queue: Array = []
var _spawn_timer: float = 0.0
var _alive: int = 0


func _ready() -> void:
	game.total_waves = WAVES.size()
	game.next_wave_in = first_wave_delay
	game.wave_name = WAVES[0].name


func _process(delta: float) -> void:
	if game.is_over:
		return
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var next: Array = _queue.pop_front()
			_spawn(next[0])
			if not _queue.is_empty():
				_spawn_timer = _queue[0][1]
	elif _alive == 0:
		if game.wave >= WAVES.size():
			game.win()
			return
		game.next_wave_in -= delta
		if game.next_wave_in <= 0.0:
			_start_next_wave()


func _start_next_wave() -> void:
	game.wave += 1
	game.next_wave_in = -1.0
	var wave: Dictionary = WAVES[game.wave - 1]
	game.wave_name = wave.name
	_queue.clear()
	var wait := 0.0
	for group: Array in wave.groups:
		var spacing: float = group[2] if group.size() > 2 else DEFAULT_SPACING
		for i in group[1]:
			_queue.append([ENEMIES[group[0]], wait])
			wait = spacing
		wait = GROUP_PAUSE
	_spawn_timer = 0.0


func _spawn(scene: PackedScene) -> void:
	var enemy: Enemy = scene.instantiate()
	var waves_in := game.wave - 1
	var early_waves := mini(waves_in, late_from_wave - 2)
	var late_waves := waves_in - early_waves
	var health_scale := 1.0 + early_waves * health_growth + late_waves * late_health_growth
	enemy.setup(health_scale, 1.0 + waves_in * speed_growth, game.upgrades)
	enemy.reached_end.connect(_on_enemy_reached_end.bind(enemy.lives_cost))
	enemy.died.connect(_on_enemy_died)
	board.get_enemy_path().add_child(enemy)
	_alive += 1


func _on_enemy_reached_end(lives_cost: int) -> void:
	_alive -= 1
	game.lose_life(lives_cost)
	_after_enemy_gone()


func _on_enemy_died(reward: int) -> void:
	_alive -= 1
	game.earn(reward)
	_after_enemy_gone()


func _after_enemy_gone() -> void:
	if _alive > 0 or not _queue.is_empty() or game.is_over:
		return
	var bonus := wave_clear_bonus + wave_clear_bonus_growth * game.wave
	game.earn(bonus)
	game.last_wave_bonus = bonus
	if game.wave < WAVES.size():
		game.next_wave_in = time_between_waves
		game.wave_name = WAVES[game.wave].name
