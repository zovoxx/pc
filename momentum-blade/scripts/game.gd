extends Node
## Global helper that Godot loads before any scene (an "autoload").
## Any script can use it by name, for example `Game.config` or `Game.hit_stop(0.05)`.
## It is registered in Project > Project Settings > Globals > Autoload.

## All tuning values. Edit res://config/game_config.tres in the Inspector.
var config: GameConfig = preload("res://config/game_config.tres") as GameConfig

# When the current hit-stop should end (milliseconds since the game started).
var _hit_stop_end_ms: int = 0


func _ready() -> void:
	# Keep running even while the game is paused, so a hit-stop always ends.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freezes the whole game for `duration` seconds.
## A tiny freeze when a hit lands ("hit-stop") makes attacks feel heavy.
func hit_stop(duration: float) -> void:
	if duration <= 0.0:
		return
	var end_ms: int = Time.get_ticks_msec() + int(duration * 1000.0)
	_hit_stop_end_ms = maxi(_hit_stop_end_ms, end_ms)
	# A time scale of 0 stops physics, timers and animations,
	# but _process() below still runs, so it can switch time back on.
	Engine.time_scale = 0.0


## Cancels any running hit-stop (used when the game starts or restarts).
func reset_time() -> void:
	_hit_stop_end_ms = 0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if Engine.time_scale == 0.0 and Time.get_ticks_msec() >= _hit_stop_end_ms:
		Engine.time_scale = 1.0
