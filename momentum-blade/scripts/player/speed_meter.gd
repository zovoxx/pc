class_name SpeedMeter
extends Node
## The speed meter: a number from 0 to 100 (the core system of the game).
##   - Stylish movement fills it: dash, slide, wall-run, wall-jump, landing hits.
##   - It drains slowly while you run normally and quickly while you stand still.
##   - Getting hit sets it back to 0.
## The fuller it is, the harder your sword hits (see get_damage_multiplier()).
## When it's full, your next attack becomes the Momentum Cut.

## Emitted when the meter reaches the top (Momentum Cut ready).
signal filled

var value: float = 0.0

@onready var cfg: GameConfig = Game.config


func add(amount: float) -> void:
	set_value(value + amount)


func reset() -> void:
	set_value(0.0)


func set_value(new_value: float) -> void:
	var was_full: bool = is_full()
	value = clampf(new_value, 0.0, cfg.meter_max)
	if is_full() and not was_full:
		filled.emit()


func is_full() -> bool:
	return value >= cfg.meter_max


## 0.0 when empty, 1.0 when full.
func get_ratio() -> float:
	return value / cfg.meter_max


## Damage tier: 1, 2 or 3. Returns 4 when the meter is full (Momentum Cut ready).
func get_tier() -> int:
	if is_full():
		return 4
	if value >= cfg.tier_3_threshold:
		return 3
	if value >= cfg.tier_2_threshold:
		return 2
	return 1


## What the sword's damage is multiplied by right now.
func get_damage_multiplier() -> float:
	match get_tier():
		1:
			return cfg.tier_1_multiplier
		2:
			return cfg.tier_2_multiplier
		_:
			return cfg.tier_3_multiplier


## Called every physics frame by the player.
func drain(delta: float, horizontal_speed: float, doing_special_move: bool) -> void:
	if doing_special_move:
		return  # dashing, sliding and wall-running never drain the meter
	if is_full() and cfg.hold_full_meter:
		return  # a full meter waits for you to use the Momentum Cut
	if value <= 0.0:
		return
	var standing_still: bool = horizontal_speed < cfg.idle_speed_threshold
	var rate: float = cfg.drain_idle if standing_still else cfg.drain_moving
	set_value(value - rate * delta)
