class_name WaveSpawner
extends Node3D
## Spawns endless waves of enemies.
## Wave 1 has `first_wave_size` enemies and each wave adds `wave_size_increase`
## more (4, 6, 8, ...). When the last enemy of a wave dies, the next wave starts
## `time_between_waves` seconds later. (These numbers live in Game.config.)

signal wave_started(wave: int, enemy_count: int)
signal wave_cleared(wave: int)
signal enemies_left_changed(count: int)

@export var grunt_scene: PackedScene
@export var shooter_scene: PackedScene
## A node whose children (Marker3D nodes) are the possible spawn positions.
@export var spawn_points: Node3D

var wave: int = 0
var enemies_left: int = 0

var _player: Player

@onready var cfg: GameConfig = Game.config
@onready var _wave_timer: Timer = $WaveTimer


func _ready() -> void:
	_wave_timer.one_shot = true
	_wave_timer.timeout.connect(_spawn_next_wave)


## Called by main.gd once everything is set up.
func start(player: Player) -> void:
	_player = player
	_wave_timer.start(cfg.first_wave_delay)


func _spawn_next_wave() -> void:
	if _player == null or not _player.is_alive():
		return
	wave += 1
	var count: int = cfg.first_wave_size + (wave - 1) * cfg.wave_size_increase
	var shooter_count: int = roundi(count * cfg.shooter_fraction)
	var points: Array[Node3D] = _pick_spawn_points()

	for i in count:
		var scene: PackedScene = shooter_scene if i < shooter_count else grunt_scene
		# Spread enemies over the spawn points, with a small random offset.
		var spot: Vector3 = global_position
		if not points.is_empty():
			spot = points[i % points.size()].global_position
		spot += Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		_spawn_enemy(scene, spot)

	enemies_left = count
	wave_started.emit(wave, count)
	enemies_left_changed.emit(enemies_left)


func _spawn_enemy(scene: PackedScene, spot: Vector3) -> void:
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	enemy.player = _player
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	enemy.global_position = spot


func _on_enemy_died(_enemy: EnemyBase) -> void:
	enemies_left -= 1
	enemies_left_changed.emit(enemies_left)
	if enemies_left <= 0:
		wave_cleared.emit(wave)
		_wave_timer.start(cfg.time_between_waves)


## Spawn points that aren't too close to the player, in random order.
func _pick_spawn_points() -> Array[Node3D]:
	var all_points: Array[Node3D] = []
	var far_points: Array[Node3D] = []
	for child in spawn_points.get_children():
		var point: Node3D = child as Node3D
		if point == null:
			continue
		all_points.append(point)
		if point.global_position.distance_to(_player.global_position) >= cfg.spawn_min_distance:
			far_points.append(point)
	# If the player is somewhere that leaves almost no far points, use them all.
	var result: Array[Node3D] = far_points
	if far_points.size() < 2:
		result = all_points
	result.shuffle()
	return result
