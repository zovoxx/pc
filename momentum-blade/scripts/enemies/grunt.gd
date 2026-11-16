class_name Grunt
extends EnemyBase
## Grunt: walks up to you and swings a big club.
## Before every swing it LEANS BACK and pulls the club back for a clear
## wind-up (0.5 s by default, with a "!" over its head). That's your cue to:
##   - dash through it (a dash makes you invincible),
##   - slide under it (the swing passes over a sliding player),
##   - jump over it, or just step out of range.
## Once the wind-up starts it's committed: hitting it won't cancel the swing.

enum State { CHASE, WINDUP, SWING, RECOVER, STAGGER }

# Club angles around the vertical axis (radians). It points forward-right at
# rest, is pulled back during the wind-up, and sweeps across to the left.
const ARM_REST: float = -0.35
const ARM_WINDUP: float = -2.4
const ARM_FOLLOW_THROUGH: float = 1.4
# Body lean (radians): positive leans back, negative leans forward.
const LEAN_BACK: float = 0.45
const LEAN_FORWARD: float = -0.25
const SWING_TIME: float = 0.2

var state: State = State.CHASE
var _state_time: float = 0.0
var _swing_dir: Vector3 = Vector3.FORWARD

@onready var lean: Node3D = $Visual/Lean
@onready var arm: Node3D = $Visual/Lean/Arm
@onready var warning: Label3D = $Visual/Warning


func _get_max_health() -> float:
	return cfg.grunt_health


func _think(delta: float) -> Vector3:
	_state_time += delta
	# Each state has its own small function that returns the wanted velocity.
	match state:
		State.CHASE:
			return _chase(delta)
		State.WINDUP:
			return _wind_up()
		State.SWING:
			return _swinging()
		State.RECOVER:
			return _recover(delta)
	return _stagger()


func _chase(delta: float) -> Vector3:
	var to_player: Vector3 = flat_offset_to_player()
	face_towards(player.global_position, delta, 10.0)
	_relax_pose(delta)
	if to_player.length() <= cfg.grunt_attack_range:
		_start_windup()
		return Vector3.ZERO
	return to_player.normalized() * cfg.grunt_move_speed


func _wind_up() -> Vector3:
	# Lean back and pull the club back: this is the warning sign.
	var t: float = ease(clampf(_state_time / cfg.grunt_windup_time, 0.0, 1.0), 0.5)
	lean.rotation.x = lerpf(0.0, LEAN_BACK, t)
	arm.rotation.y = lerpf(ARM_REST, ARM_WINDUP, t)
	if _state_time >= cfg.grunt_windup_time:
		_swing()
	return Vector3.ZERO


func _swinging() -> Vector3:
	# A short lunge forward while the club sweeps across.
	if _state_time >= SWING_TIME:
		_change_state(State.RECOVER)
	return _swing_dir * cfg.grunt_lunge_speed


func _recover(delta: float) -> Vector3:
	# Standing still after the swing: punish it now!
	_relax_pose(delta)
	if _state_time >= cfg.grunt_recover_time:
		_change_state(State.CHASE)
	return Vector3.ZERO


func _stagger() -> Vector3:
	# Flinching after being hit while walking.
	if _state_time >= cfg.enemy_stagger_time:
		_change_state(State.CHASE)
	return Vector3.ZERO


func _start_windup() -> void:
	_change_state(State.WINDUP)
	# Lock in the swing direction now (straight at the player), so a quick
	# sidestep can also dodge it.
	var to_player: Vector3 = flat_offset_to_player()
	if to_player.length() > 0.01:
		_swing_dir = to_player.normalized()
	else:
		_swing_dir = get_facing()
	visual.rotation.y = atan2(-_swing_dir.x, -_swing_dir.z)
	warning.visible = true


func _swing() -> void:
	_change_state(State.SWING)
	warning.visible = false
	lean.rotation.x = LEAN_FORWARD
	var tween: Tween = create_tween()
	tween.tween_property(arm, "rotation:y", ARM_FOLLOW_THROUGH, 0.1)
	_try_hit_player()


func _try_hit_player() -> void:
	var to_player: Vector3 = flat_offset_to_player()
	var distance: float = to_player.length()
	if distance > cfg.grunt_swing_reach:
		return  # out of range
	var angle: float = rad_to_deg(_swing_dir.angle_to(to_player))
	if distance > 0.3 and angle > cfg.grunt_swing_arc_degrees * 0.5:
		return  # outside the swing's arc
	# The club sweeps at a fixed height above the ground.
	var swing_y: float = global_position.y + cfg.grunt_swing_height
	if player.get_hurtbox_top() < swing_y:
		return  # the player slid under the swing
	if player.global_position.y > swing_y:
		return  # the player jumped over the swing
	player.take_hit(global_position)


func _on_damaged() -> void:
	# Getting hit while walking makes it flinch. During a wind-up, swing or
	# recovery it keeps going (it's committed), so dodge or out-damage it.
	if state == State.CHASE:
		_change_state(State.STAGGER)


func _relax_pose(delta: float) -> void:
	var blend: float = 1.0 - exp(-10.0 * delta)
	lean.rotation.x = lerpf(lean.rotation.x, 0.0, blend)
	arm.rotation.y = lerp_angle(arm.rotation.y, ARM_REST, blend)


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
