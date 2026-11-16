extends Node3D
## Script of the main scene. It wires the game together:
##   - connects the HUD to the player and the wave spawner, then starts the waves
##   - captures the mouse and pauses with Esc
##   - shows the game-over screen and restarts with R
##
## Note: this node is set to "Process Mode: Always" so it can unpause the game.
## The game world nodes under it (Arena, Player, WaveSpawner) are set to
## "Pausable", so they stop while the game is paused.

var _game_over: bool = false

@onready var player: Player = $Player
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var hud: HUD = $HUD


func _ready() -> void:
	Game.reset_time()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.bind(player, spawner)
	player.died.connect(_on_player_died)
	spawner.start(player)


func _input(event: InputEvent) -> void:
	if _game_over:
		if event.is_action_pressed("restart"):
			Game.reset_time()
			get_tree().paused = false
			get_tree().reload_current_scene()
		return

	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif get_tree().paused and event is InputEventMouseButton and not event.is_pressed():
		# Click to resume. We resume on mouse *release*, so that click doesn't
		# also swing the sword.
		_set_paused(false)


func _notification(what: int) -> void:
	# Pause automatically when the window loses focus (e.g. Alt+Tab).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not _game_over:
		_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	hud.set_paused(paused)


func _on_player_died() -> void:
	_game_over = true
	hud.show_game_over(spawner.wave)
