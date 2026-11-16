class_name HUD
extends CanvasLayer
## Everything drawn on top of the game: speed meter, health, wave info,
## pop-up messages, the pause screen and the game-over screen.

## Speed bar colour for each tier: x1, x2, x3, and FULL (Momentum Cut ready).
@export var tier_colors: Array[Color] = [
	Color(0.35, 0.65, 1.0),
	Color(1.0, 0.85, 0.25),
	Color(1.0, 0.45, 0.15),
	Color(1.0, 0.25, 0.85),
]
## Colour of a health pip you still have / have lost.
@export var health_full_color: Color = Color(0.3, 1.0, 0.55)
@export var health_empty_color: Color = Color(1.0, 1.0, 1.0, 0.15)
## Seconds before the controls hint fades away.
@export var hint_time: float = 12.0

var _meter: SpeedMeter
var _shown_meter: float = 0.0  # the bar slides smoothly toward the real value
var _pulse_time: float = 0.0
var _fill_style: StyleBoxFlat
var _message_tween: Tween
var _hurt_tween: Tween

@onready var speed_bar: ProgressBar = $SpeedBox/SpeedBar
@onready var tier_label: Label = $SpeedBox/TierLabel
@onready var health_pips: HBoxContainer = $HealthBox/HealthPips
@onready var wave_label: Label = $WaveBox/WaveLabel
@onready var enemies_label: Label = $WaveBox/EnemiesLabel
@onready var message_label: Label = $Message
@onready var hint_label: Label = $Hint
@onready var hurt_flash: ColorRect = $HurtFlash
@onready var pause_panel: Control = $PausePanel
@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Label


func _ready() -> void:
	# Use our own copy of the bar's fill style, so we can recolour it per tier.
	_fill_style = (speed_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	speed_bar.add_theme_stylebox_override("fill", _fill_style)
	message_label.modulate.a = 0.0
	pause_panel.visible = false
	game_over_panel.visible = false
	# Fade out the controls hint after a while.
	var tween: Tween = create_tween()
	tween.tween_interval(hint_time)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.5)


## Connects the HUD to the player and the wave spawner (called by main.gd).
func bind(player: Player, spawner: WaveSpawner) -> void:
	_meter = player.meter
	_meter.filled.connect(_on_meter_filled)
	player.health_changed.connect(_on_health_changed)
	player.hurt.connect(_on_player_hurt)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.enemies_left_changed.connect(_on_enemies_left_changed)

	var max_health: int = Game.config.max_health
	for i in max_health:
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(30.0, 30.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_pips.add_child(pip)
	_on_health_changed(player.health, max_health)
	wave_label.text = "WAVE -"
	enemies_label.text = "Get ready..."


func _process(delta: float) -> void:
	if _meter != null:
		_update_speed_bar(delta)


func _update_speed_bar(delta: float) -> void:
	_shown_meter = lerpf(_shown_meter, _meter.value, 1.0 - exp(-14.0 * delta))
	speed_bar.max_value = Game.config.meter_max
	speed_bar.value = _shown_meter

	var tier: int = _meter.get_tier()
	var color: Color = tier_colors[clampi(tier - 1, 0, tier_colors.size() - 1)]
	if tier == 4:
		# Full: pulse brightly and tell the player what to do.
		_pulse_time += delta
		var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 12.0)
		color = color.lerp(Color.WHITE, pulse * 0.6)
		tier_label.text = "MOMENTUM CUT READY  -  CLICK!"
	else:
		tier_label.text = "SPEED  x" + _format_number(_meter.get_damage_multiplier())
	_fill_style.bg_color = color
	tier_label.modulate = color


## Shows a big message in the middle of the screen that fades out.
func show_message(text: String, duration: float = 1.5) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func set_paused(paused: bool) -> void:
	pause_panel.visible = paused


func show_game_over(wave: int) -> void:
	game_over_label.text = "YOU DIED\n\nYou reached wave %d\n\nPress R to restart" % wave
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.6)


## "2" for 2.0, "1.5" for 1.5.
func _format_number(number: float) -> String:
	if is_equal_approx(number, roundf(number)):
		return "%d" % roundi(number)
	return "%.1f" % number


func _on_health_changed(current: int, _maximum: int) -> void:
	for i in health_pips.get_child_count():
		var pip: ColorRect = health_pips.get_child(i) as ColorRect
		pip.color = health_full_color if i < current else health_empty_color


func _on_player_hurt() -> void:
	# Quick red flash over the whole screen.
	if _hurt_tween != null:
		_hurt_tween.kill()
	hurt_flash.color.a = 0.4
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.5)


func _on_meter_filled() -> void:
	show_message("MAX SPEED!", 0.8)


func _on_wave_started(wave: int, _enemy_count: int) -> void:
	wave_label.text = "WAVE %d" % wave
	show_message("WAVE %d" % wave)


func _on_wave_cleared(wave: int) -> void:
	show_message("WAVE %d CLEARED" % wave, 2.0)


func _on_enemies_left_changed(count: int) -> void:
	enemies_label.text = "Enemies left: %d" % count
