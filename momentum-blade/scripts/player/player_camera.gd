class_name PlayerCamera
extends Node3D
## Third-person camera rig. It's a child of the Player, so it follows them.
##   - The mouse turns it: this node turns left/right ("yaw"),
##     the Pitch child node tilts up/down.
##   - A SpringArm3D pulls the camera closer when a wall is in the way.
##   - It shakes on hits, and its field of view widens as the speed meter fills.

## Lowest the camera can look (degrees, negative = looking down).
@export var min_pitch_degrees: float = -65.0
## Highest the camera can look (degrees).
@export var max_pitch_degrees: float = 30.0
## Starting tilt of the camera (degrees).
@export var start_pitch_degrees: float = -15.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _trauma: float = 0.0          # current shake strength, 0..1
var _target_tilt: float = 0.0     # sideways camera roll (used while wall-running)
var _current_tilt: float = 0.0
var _shake_time: float = 0.0
var _last_ticks_usec: int = 0
var _noise: FastNoiseLite = FastNoiseLite.new()

@onready var cfg: GameConfig = Game.config
@onready var player: Player = get_parent() as Player
@onready var pitch_pivot: Node3D = $Pitch
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	_yaw = global_rotation.y
	_pitch = deg_to_rad(start_pitch_degrees)
	_noise.frequency = 15.0
	camera.fov = cfg.base_fov
	_last_ticks_usec = Time.get_ticks_usec()
	_apply_rotation()


func _input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= motion.relative.x * cfg.mouse_sensitivity
		_pitch -= motion.relative.y * cfg.mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
		_apply_rotation()


func _apply_rotation() -> void:
	rotation.y = _yaw
	pitch_pivot.rotation.x = _pitch


## The camera's left/right rotation only. The player uses it to turn
## "W = forward" into "forward from where the camera looks".
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


## Start (or strengthen) a camera shake. 0 = nothing, 1 = maximum.
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Roll the camera sideways a little (radians). Used while wall-running.
func set_tilt(radians: float) -> void:
	_target_tilt = radians


func _process(_delta: float) -> void:
	# We measure real time ourselves instead of using `delta`, because during a
	# hit-stop the game's time is frozen (delta = 0) but the shake should keep going.
	var now: int = Time.get_ticks_usec()
	var real_delta: float = minf((now - _last_ticks_usec) / 1000000.0, 0.1)
	_last_ticks_usec = now

	_update_fov(real_delta)
	_update_shake(real_delta)


func _update_fov(delta: float) -> void:
	# Wider view = feels faster. The fuller the meter, the wider the view.
	var target_fov: float = cfg.base_fov + cfg.fov_bonus_at_full * player.meter.get_ratio()
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-5.0 * delta))


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - cfg.shake_decay * delta, 0.0)
	_shake_time += delta
	# Squaring makes small shakes subtle and big shakes strong.
	var strength: float = _trauma * _trauma
	# Noise gives a smooth random wobble (nicer than pure random jumps).
	camera.h_offset = cfg.shake_max_offset * strength * _noise.get_noise_2d(_shake_time, 0.0)
	camera.v_offset = cfg.shake_max_offset * strength * _noise.get_noise_2d(0.0, _shake_time)
	var roll: float = 0.06 * strength * _noise.get_noise_2d(_shake_time, _shake_time)
	_current_tilt = lerpf(_current_tilt, _target_tilt, 1.0 - exp(-8.0 * delta))
	camera.rotation.z = _current_tilt + roll
