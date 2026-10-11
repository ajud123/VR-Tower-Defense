extends Node
## Sends waves of enemies down the board's path. Each wave is bigger and
## tougher than the last, and tanks join from wave 2. Clearing the final
## wave wins the game.

@export var board: Board
@export var game: GameState
@export var blob_scene: PackedScene
@export var tank_scene: PackedScene
@export var wave_count: int = 10
@export var first_wave_delay: float = 15.0
@export var time_between_waves: float = 10.0
## Seconds between enemies within a wave.
@export var spawn_interval: float = 1.1
## Extra enemy health per wave after the first (0.3 = +30% each wave).
@export var health_growth: float = 0.6
## Extra enemy speed per wave after the first.
@export var speed_growth: float = 0.04
## Gold paid for clearing a wave: base + growth * wave number.
@export var wave_clear_bonus: int = 30
@export var wave_clear_bonus_growth: int = 10

var _queue: Array[PackedScene] = []
var _spawn_timer: float = 0.0
var _alive: int = 0


func _ready() -> void:
	game.total_waves = wave_count
	game.next_wave_in = first_wave_delay


func _process(delta: float) -> void:
	if game.is_over:
		return
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn(_queue.pop_front())
	elif _alive == 0:
		if game.wave >= wave_count:
			game.win()
			return
		game.next_wave_in -= delta
		if game.next_wave_in <= 0.0:
			_start_next_wave()


func _start_next_wave() -> void:
	game.wave += 1
	game.next_wave_in = -1.0
	var blobs := 6 + game.wave * 2
	var tanks := maxi(game.wave - 1, 0)
	# Spread the tanks evenly through the wave.
	_queue.clear()
	for i in blobs + tanks:
		var tank_due := tanks > 0 and (i + 1) * tanks / (blobs + tanks) > _queue.count(tank_scene)
		_queue.append(tank_scene if tank_due else blob_scene)
	_spawn_timer = 0.0


func _spawn(scene: PackedScene) -> void:
	var enemy: Enemy = scene.instantiate()
	var waves_in := game.wave - 1
	enemy.setup(1.0 + waves_in * health_growth, 1.0 + waves_in * speed_growth, game.upgrades)
	enemy.reached_end.connect(_on_enemy_reached_end)
	enemy.died.connect(_on_enemy_died)
	board.get_enemy_path().add_child(enemy)
	_alive += 1


func _on_enemy_reached_end() -> void:
	_alive -= 1
	game.lose_life()
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
	if game.wave < wave_count:
		game.next_wave_in = time_between_waves
