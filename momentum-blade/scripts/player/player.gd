class_name Player
extends CharacterBody3D
## The player character.
##
## This script handles MOVEMENT (run, jump, dash, slide, wall-run), HEALTH and
## getting hit. Other jobs live in child nodes, each with its own script:
##   SpeedMeter  (speed_meter.gd)    the 0-100 momentum meter
##   Combat      (player_combat.gd)  sword slash and Momentum Cut
##   CameraRig   (player_camera.gd)  mouse look, camera shake and FOV
## All tuning numbers come from Game.config (res://config/game_config.tres).

signal health_changed(current: int, maximum: int)
signal hurt
signal died
## Emitted when the Momentum Cut's dash reaches its end.
signal cut_finished

## The player is always in exactly one of these states ("state machine").
enum State { NORMAL, DASH, SLIDE, WALL_RUN, CUT, DEAD }

const STAND_HEIGHT: float = 1.8

var state: State = State.NORMAL
var health: int = 0
## Flat direction the character model faces.
var facing: Vector3 = Vector3.FORWARD

var _state_time: float = 0.0           # seconds spent in the current state
var _move_dir: Vector3 = Vector3.FORWARD  # direction of the current dash / slide / wall-run / cut
var _move_speed: float = 0.0           # speed of the current dash / slide / wall-run / cut
var _wall_normal: Vector3 = Vector3.ZERO       # points away from the wall we run on
var _last_wall_normal: Vector3 = Vector3.ZERO  # the wall we last ran on
var _air_dashes_left: int = 0
var _short_hop_allowed: bool = false   # true right after a normal jump

# Countdown timers in seconds. Each counts down; "> 0" means "still active".
var _dash_cooldown: float = 0.0
var _slide_cooldown: float = 0.0
var _invincible_time: float = 0.0
var _blink_time: float = 0.0
var _coyote_time: float = 0.0
var _jump_buffer: float = 0.0
var _slide_buffer: float = 0.0
var _wall_run_lockout: float = 0.0
var _face_lock_time: float = 0.0
var _keep_momentum_time: float = 0.0
var _afterimage_timer: float = 0.0

@onready var cfg: GameConfig = Game.config
@onready var meter: SpeedMeter = $SpeedMeter
@onready var camera_rig: PlayerCamera = $CameraRig
@onready var body: Node3D = $Body
@onready var body_mesh: MeshInstance3D = $Body/Mesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
@onready var _spawn_position: Vector3 = global_position


func _ready() -> void:
	health = cfg.max_health
	_air_dashes_left = cfg.air_dashes
	# Use our own copy of the collision shape, because sliding changes its size.
	_capsule = _capsule.duplicate() as CapsuleShape3D
	collision.shape = _capsule


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_process_dead(delta)
		return

	_update_timers(delta)

	# Run the code for the current state. It sets `velocity`.
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.DASH:
			_process_dash(delta)
		State.SLIDE:
			_process_slide(delta)
		State.WALL_RUN:
			_process_wall_run(delta)
		State.CUT:
			_process_cut()

	# Built-in CharacterBody3D movement: moves by `velocity`, sliding along walls.
	move_and_slide()

	_update_meter(delta)
	_update_body_visuals(delta)
	_check_fell_out_of_arena()


# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------

## The movement keys as a flat world direction, relative to where the camera looks.
func get_move_input() -> Vector3:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = camera_rig.get_yaw_basis() * Vector3(input.x, 0.0, input.y)
	if dir.length() < 0.1:
		return Vector3.ZERO
	return dir.normalized()


## Flat direction the camera looks. Attacks go this way.
func get_aim_direction() -> Vector3:
	return camera_rig.get_yaw_basis() * Vector3.FORWARD


func _update_timers(delta: float) -> void:
	_state_time += delta
	_dash_cooldown -= delta
	_slide_cooldown -= delta
	_invincible_time -= delta
	_blink_time -= delta
	_coyote_time -= delta
	_jump_buffer -= delta
	_slide_buffer -= delta
	_wall_run_lockout -= delta
	_face_lock_time -= delta
	_keep_momentum_time -= delta

	# Remember presses for a moment ("input buffering"): pressing jump slightly
	# before landing still jumps. Makes the controls feel much more responsive.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = cfg.input_buffer_time
	if Input.is_action_just_pressed("slide"):
		_slide_buffer = cfg.input_buffer_time

	if is_on_floor():
		_coyote_time = cfg.coyote_time
		_air_dashes_left = cfg.air_dashes
		_last_wall_normal = Vector3.ZERO


# ---------------------------------------------------------------------------
# NORMAL: running, jumping, falling
# ---------------------------------------------------------------------------

func _process_normal(delta: float) -> void:
	var input_dir: Vector3 = get_move_input()
	var on_floor: bool = is_on_floor()

	# 1) Special moves take priority over plain running.
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash(input_dir)
		return
	if _slide_buffer > 0.0 and on_floor and _slide_cooldown <= 0.0:
		_start_slide(input_dir)
		return
	if not on_floor and _can_start_wall_run(input_dir):
		_start_wall_run()
		return

	# 2) Jumping. Coyote time lets you jump just after running off a ledge.
	if _jump_buffer > 0.0 and _coyote_time > 0.0:
		_jump()
	# Letting go of Space early gives a shorter hop.
	if _short_hop_allowed and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= cfg.jump_release_damping
		_short_hop_allowed = false

	# 3) Gravity and running.
	_apply_gravity(delta)
	_apply_run_movement(input_dir, on_floor, delta)
	if input_dir != Vector3.ZERO and _face_lock_time <= 0.0:
		facing = input_dir


func _jump() -> void:
	velocity.y = cfg.jump_velocity
	_jump_buffer = 0.0
	_coyote_time = 0.0
	_short_hop_allowed = true


func _apply_gravity(delta: float) -> void:
	var g: float = cfg.gravity
	if velocity.y < 0.0:
		g *= cfg.fall_gravity_multiplier  # fall faster than you rise: less floaty
	velocity.y = maxf(velocity.y - g * delta, -cfg.max_fall_speed)


func _apply_run_movement(input_dir: Vector3, on_floor: bool, delta: float) -> void:
	var horizontal: Vector3 = _flat_velocity()
	var has_input: bool = input_dir != Vector3.ZERO

	# Normally we aim for run_speed. If we're already going faster (after a dash,
	# slide or wall-jump) we keep that extra speed and only bleed it off slowly.
	# This is what makes chaining moves feel fast.
	var top_speed: float = cfg.run_speed
	var current_speed: float = horizontal.length()
	if current_speed > cfg.run_speed:
		var bleed: float = cfg.overspeed_decel_ground if on_floor else cfg.overspeed_decel_air
		top_speed = maxf(cfg.run_speed, current_speed - bleed * delta)

	if not on_floor and _keep_momentum_time > 0.0:
		# Right after a wall-jump: steering may only ADD speed in the direction
		# you hold (up to run speed). It never brakes, so the jump keeps its push.
		if has_input:
			var speed_along_input: float = horizontal.dot(input_dir)
			var boost: float = cfg.run_speed - speed_along_input
			boost = clampf(boost, 0.0, cfg.air_acceleration * delta)
			horizontal += input_dir * boost
	else:
		var accel: float
		if has_input:
			accel = cfg.ground_acceleration if on_floor else cfg.air_acceleration
		else:
			accel = cfg.ground_friction if on_floor else cfg.air_drag
		# Move our velocity toward the target velocity by at most accel * delta.
		horizontal = horizontal.move_toward(input_dir * top_speed, accel * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z


# ---------------------------------------------------------------------------
# DASH: short, fast, invincible burst
# ---------------------------------------------------------------------------

func _can_dash() -> bool:
	return _dash_cooldown <= 0.0 and (is_on_floor() or _air_dashes_left > 0)


func _start_dash(input_dir: Vector3) -> void:
	# Dash where you're steering. With no keys held, dash where the camera looks.
	_move_dir = input_dir if input_dir != Vector3.ZERO else get_aim_direction()
	_move_speed = cfg.dash_speed
	if not is_on_floor():
		_air_dashes_left -= 1
	_dash_cooldown = cfg.dash_cooldown
	_invincible_time = maxf(_invincible_time, cfg.dash_invincibility)
	meter.add(cfg.gain_dash)
	facing = _move_dir
	velocity = _move_dir * _move_speed
	_change_state(State.DASH)


func _process_dash(_delta: float) -> void:
	# Cancel a dash into a slide or a jump to keep its speed. Great for combos.
	if _slide_buffer > 0.0 and is_on_floor() and _slide_cooldown <= 0.0:
		_start_slide(get_move_input())
		return
	if _jump_buffer > 0.0 and is_on_floor():
		velocity = _move_dir * cfg.dash_exit_speed
		_jump()
		_change_state(State.NORMAL)
		return

	# A dash flies straight: no gravity while it lasts.
	velocity = _move_dir * _move_speed
	if _state_time >= cfg.dash_duration:
		velocity = _move_dir * cfg.dash_exit_speed
		_change_state(State.NORMAL)


# ---------------------------------------------------------------------------
# SLIDE: low and fast, keeps momentum, goes under grunt swings
# ---------------------------------------------------------------------------

func _start_slide(input_dir: Vector3) -> void:
	var horizontal: Vector3 = _flat_velocity()
	# Slide the way you're already moving, else where you steer, else where you look.
	if horizontal.length() > 2.0:
		_move_dir = horizontal.normalized()
	elif input_dir != Vector3.ZERO:
		_move_dir = input_dir
	else:
		_move_dir = get_aim_direction()
	# Slides keep momentum: if you're already faster than a normal slide, keep it.
	_move_speed = clampf(horizontal.length(), cfg.slide_speed, cfg.slide_max_speed)
	_slide_buffer = 0.0
	_slide_cooldown = cfg.slide_cooldown
	meter.add(cfg.gain_slide)
	facing = _move_dir
	_set_crouched(true)
	_change_state(State.SLIDE)


func _process_slide(delta: float) -> void:
	# Jumping out of a slide keeps the slide's speed ("slide-jump").
	if _jump_buffer > 0.0 and is_on_floor():
		_end_slide()
		velocity = _move_dir * _move_speed
		_jump()
		return
	if Input.is_action_just_pressed("dash") and _can_dash():
		_end_slide()
		_start_dash(get_move_input())
		return

	# Steer a little with the movement keys.
	var input_dir: Vector3 = get_move_input()
	if input_dir != Vector3.ZERO:
		var angle: float = _move_dir.signed_angle_to(input_dir, Vector3.UP)
		var max_turn: float = cfg.slide_steer * delta
		_move_dir = _move_dir.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn))
		facing = _move_dir

	_move_speed = maxf(_move_speed - cfg.slide_friction * delta, 0.0)
	velocity.x = _move_dir.x * _move_speed
	velocity.z = _move_dir.z * _move_speed
	_apply_gravity(delta)

	var too_slow: bool = _move_speed < cfg.run_speed * 0.6
	if _state_time >= cfg.slide_duration or too_slow or not is_on_floor():
		_end_slide()


func _end_slide() -> void:
	_set_crouched(false)
	_change_state(State.NORMAL)


## Makes the collision capsule short (sliding) or normal height (standing).
func _set_crouched(crouched: bool) -> void:
	var height: float = cfg.slide_height if crouched else STAND_HEIGHT
	_capsule.height = height
	collision.position.y = height * 0.5


# ---------------------------------------------------------------------------
# WALL_RUN: run along a wall while airborne, then jump off it
# ---------------------------------------------------------------------------

func _can_start_wall_run(input_dir: Vector3) -> bool:
	if not is_on_wall() or _wall_run_lockout > 0.0 or input_dir == Vector3.ZERO:
		return false
	var normal: Vector3 = _flat(get_wall_normal())
	if normal == Vector3.ZERO:
		return false
	# You can't run on the same wall twice in a row without landing first.
	if _last_wall_normal != Vector3.ZERO and normal.dot(_last_wall_normal) > 0.9:
		return false
	# Don't grab the wall if you're steering away from it.
	if input_dir.dot(normal) > 0.5:
		return false
	# You need enough speed ALONG the wall. Running straight into it doesn't count.
	var horizontal: Vector3 = _flat_velocity()
	var along_wall: Vector3 = horizontal - normal * horizontal.dot(normal)
	return along_wall.length() >= cfg.wall_run_min_speed


func _start_wall_run() -> void:
	_wall_normal = _flat(get_wall_normal())
	_last_wall_normal = _wall_normal
	var horizontal: Vector3 = _flat_velocity()
	var along_wall: Vector3 = horizontal - _wall_normal * horizontal.dot(_wall_normal)
	_move_dir = along_wall.normalized()
	_move_speed = maxf(along_wall.length(), cfg.wall_run_speed)
	velocity.y = maxf(velocity.y, cfg.wall_run_start_lift)
	_air_dashes_left = cfg.air_dashes
	facing = _move_dir
	_set_wall_run_velocity()
	_change_state(State.WALL_RUN)


func _process_wall_run(delta: float) -> void:
	# Jump off the wall: up, away from it, and keeping the running speed.
	if _jump_buffer > 0.0:
		_wall_jump()
		return
	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash(get_move_input())
		return

	# Stop when: out of time, landed, ran off the end of the wall, or let go of the keys.
	var out_of_time: bool = _state_time > cfg.wall_run_max_time
	var let_go: bool = get_move_input() == Vector3.ZERO
	if out_of_time or is_on_floor() or not is_on_wall() or let_go:
		_stop_wall_run()
		return

	# Follow the wall if its direction changes slightly.
	_wall_normal = _flat(get_wall_normal())
	_move_dir = (_move_dir - _wall_normal * _move_dir.dot(_wall_normal)).normalized()
	if _move_dir == Vector3.ZERO:
		_stop_wall_run()
		return

	# We fall slowly, because wall-run gravity is much weaker than normal.
	_set_wall_run_velocity()
	velocity.y -= cfg.wall_run_gravity * delta
	meter.add(cfg.gain_wall_run_per_second * delta)


## Run along the wall while pressing gently into it, so we stay attached
## (move_and_slide only reports "on wall" while we push against it).
func _set_wall_run_velocity() -> void:
	velocity.x = _move_dir.x * _move_speed - _wall_normal.x * 2.0
	velocity.z = _move_dir.z * _move_speed - _wall_normal.z * 2.0


func _stop_wall_run() -> void:
	var vertical: float = velocity.y
	velocity = _move_dir * _move_speed  # drop the push into the wall
	velocity.y = vertical
	_wall_run_lockout = 0.15
	_change_state(State.NORMAL)


func _wall_jump() -> void:
	velocity = _move_dir * _move_speed + _wall_normal * cfg.wall_jump_push
	velocity.y = cfg.wall_jump_up
	_jump_buffer = 0.0
	_wall_run_lockout = 0.2
	_keep_momentum_time = cfg.wall_jump_momentum_time
	meter.add(cfg.gain_wall_jump)
	facing = _flat(velocity)
	_change_state(State.NORMAL)


# ---------------------------------------------------------------------------
# CUT: the Momentum Cut's dash (started by PlayerCombat)
# ---------------------------------------------------------------------------

## Called by PlayerCombat. Dashes `distance` meters along `direction`.
func start_momentum_cut(direction: Vector3, distance: float) -> void:
	if state == State.SLIDE:
		_set_crouched(false)
	_move_dir = direction
	_move_speed = distance / maxf(cfg.cut_duration, 0.01)
	facing = direction
	_invincible_time = maxf(_invincible_time, cfg.cut_duration + 0.2)
	velocity = _move_dir * _move_speed
	_change_state(State.CUT)


func _process_cut() -> void:
	velocity = _move_dir * _move_speed  # straight line, no gravity
	if _state_time >= cfg.cut_duration:
		velocity = _move_dir * cfg.dash_exit_speed
		_change_state(State.NORMAL)
		cut_finished.emit()


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

func is_alive() -> bool:
	return state != State.DEAD


func is_invincible() -> bool:
	return _invincible_time > 0.0 or state == State.DASH or state == State.CUT


## True when attacks are allowed right now.
func can_attack() -> bool:
	return state != State.CUT and state != State.DEAD


## Height (world Y) of the top of the player's body. Grunts use it to check
## whether their swing passes over a sliding player.
func get_hurtbox_top() -> float:
	return global_position.y + _capsule.height


## Called by enemies and projectiles. Returns true if the hit actually landed
## (false if the player was invincible, e.g. dashing).
func take_hit(from_position: Vector3) -> bool:
	if not is_alive() or is_invincible():
		return false

	health -= 1
	health_changed.emit(health, cfg.max_health)
	meter.reset()  # getting hit kills all your momentum
	hurt.emit()
	camera_rig.add_shake(cfg.shake_hurt)
	Game.hit_stop(cfg.hit_stop_hurt)
	if state == State.SLIDE:
		# Deferred: this can be called from inside a physics callback,
		# where changing collision shapes directly isn't allowed.
		_set_crouched.call_deferred(false)

	# Get knocked away from whatever hit us.
	var away: Vector3 = _flat(global_position - from_position)
	if away == Vector3.ZERO:
		away = -facing
	velocity = away * cfg.hurt_knockback + Vector3.UP * 4.0
	_change_state(State.NORMAL)

	if health <= 0:
		_die()
	else:
		_invincible_time = cfg.hurt_invincibility
		_blink_time = cfg.hurt_invincibility
	return true


func _die() -> void:
	_change_state(State.DEAD)
	body.visible = true
	died.emit()
	# Topple over backwards.
	var tween: Tween = create_tween()
	tween.tween_property(body, "rotation:x", deg_to_rad(80.0), 0.5) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process_dead(delta: float) -> void:
	_apply_gravity(delta)
	var horizontal: Vector3 = _flat_velocity().move_toward(Vector3.ZERO, 20.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


# ---------------------------------------------------------------------------
# Meter, visuals and small helpers
# ---------------------------------------------------------------------------

func _update_meter(delta: float) -> void:
	# Special moves never drain the meter. Running drains it slowly,
	# standing still drains it fast (see SpeedMeter.drain).
	var doing_special_move: bool = state != State.NORMAL
	meter.drain(delta, _flat_velocity().length(), doing_special_move)


## Instantly turn the model to face a direction (used when attacking).
func face_instantly(direction: Vector3) -> void:
	facing = direction
	body.rotation.y = atan2(-direction.x, -direction.z)
	_face_lock_time = 0.25  # keep facing the attack for a moment


func _update_body_visuals(delta: float) -> void:
	# Smoothly turn the model to face `facing`.
	var target_yaw: float = atan2(-facing.x, -facing.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-cfg.turn_speed * delta))

	# Lean the model: back when sliding, forward when dashing, sideways on a wall.
	var lean: float = 0.0
	var tilt: float = 0.0
	match state:
		State.SLIDE:
			lean = 1.15  # about 65 degrees back: a low slide
		State.DASH, State.CUT:
			lean = -0.3  # lean forward
		State.WALL_RUN:
			var right: Vector3 = facing.cross(Vector3.UP)
			tilt = -_wall_normal.dot(right) * 0.4  # tilt away from the wall
	var blend: float = 1.0 - exp(-18.0 * delta)
	body.rotation.x = lerpf(body.rotation.x, lean, blend)
	body.rotation.z = lerpf(body.rotation.z, tilt, blend)
	camera_rig.set_tilt(tilt * 0.25)

	# Blink while invincible after getting hit.
	body.visible = _blink_time <= 0.0 or fmod(_blink_time, 0.14) > 0.07

	# Leave see-through "afterimages" behind during dashes and the Momentum Cut.
	if state == State.DASH or state == State.CUT:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.03
			var ghost_color: Color = Color(0.4, 0.8, 1.0, 0.45)
			FX.afterimage(get_parent(), body_mesh.mesh, body_mesh.global_transform, ghost_color)


func _check_fell_out_of_arena() -> void:
	# Safety net: if we ever fall through the floor, put the player back.
	if global_position.y < -30.0:
		global_position = _spawn_position
		velocity = Vector3.ZERO


func _change_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if new_state != State.NORMAL:
		_short_hop_allowed = false


func _flat_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## The vector flattened onto the ground plane and normalized (or ZERO).
func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z).normalized()
