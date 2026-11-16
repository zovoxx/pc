class_name PlayerCombat
extends Node
## The player's sword.
##   - Left click: a quick slash in an arc in front of you (where the camera looks).
##   - Left click with a FULL speed meter: the Momentum Cut, a long dash that
##     slices every enemy on the line.
## Slash damage is multiplied by the speed meter's tier (x1 / x2 / x3).

## How far the sword swings to each side in the slash animation (degrees).
@export var swing_angle_degrees: float = 85.0
## Resting pose of the sword: tip pointing down (x) and to the right (y), in degrees.
@export var rest_pose_degrees: Vector3 = Vector3(-25.0, -35.0, 0.0)

var _cooldown: float = 0.0
var _attack_buffer: float = 0.0
var _swing_side: float = 1.0  # +1 / -1: slashes alternate right-to-left and left-to-right
var _sword_tween: Tween

@onready var cfg: GameConfig = Game.config
@onready var player: Player = get_parent() as Player
@onready var sword_pivot: Node3D = $"../Body/SwordPivot"
@onready var slash_arc: SlashArc = $"../Body/SlashArc"


func _ready() -> void:
	sword_pivot.rotation = _rest_rotation()


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_attack_buffer -= delta
	# Only attack while the mouse is captured (not while clicking back into the window).
	if Input.is_action_just_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_attack_buffer = cfg.input_buffer_time

	if _attack_buffer <= 0.0 or not player.can_attack():
		return
	if player.meter.is_full():
		_attack_buffer = 0.0
		_momentum_cut()
	elif _cooldown <= 0.0:
		_attack_buffer = 0.0
		_slash()


# ---------------------------------------------------------------------------
# Normal slash
# ---------------------------------------------------------------------------

func _slash() -> void:
	_cooldown = cfg.slash_cooldown
	var aim: Vector3 = player.get_aim_direction()
	player.face_instantly(aim)
	_play_swing_animation()
	slash_arc.play(_swing_side, cfg.slash_range)
	_swing_side = -_swing_side

	# Work out the damage BEFORE adding meter from these hits,
	# so every enemy in this slash takes the same damage.
	var damage: float = cfg.slash_damage * player.meter.get_damage_multiplier()
	var hits: int = 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy.is_dead:
			continue
		if _is_in_slash_arc(enemy.global_position, aim, enemy.hit_radius):
			var push_dir: Vector3 = _flat_direction(enemy.global_position - player.global_position, aim)
			enemy.take_damage(damage, push_dir * cfg.slash_knockback)
			hits += 1

	# The sword also destroys enemy projectiles.
	for node in get_tree().get_nodes_in_group("projectiles"):
		var projectile: Projectile = node as Projectile
		if projectile != null and _is_in_slash_arc(projectile.global_position, aim, 0.4):
			projectile.pop()

	if hits > 0:
		player.meter.add(cfg.gain_enemy_hit * hits)
		Game.hit_stop(cfg.hit_stop_slash)
		player.camera_rig.add_shake(cfg.shake_slash)


## True if a point is inside the slash: close enough, roughly level with the
## player, and within the arc's angle in front of the player.
func _is_in_slash_arc(point: Vector3, aim: Vector3, target_radius: float) -> bool:
	var offset: Vector3 = point - player.global_position
	if absf(offset.y) > 2.0:
		return false
	offset.y = 0.0
	var distance: float = offset.length()
	if distance > cfg.slash_range + target_radius:
		return false
	if distance < 0.5:
		return true  # practically on top of us: always a hit
	var angle: float = rad_to_deg(aim.angle_to(offset))
	return angle <= cfg.slash_arc_degrees * 0.5


# ---------------------------------------------------------------------------
# Momentum Cut
# ---------------------------------------------------------------------------

func _momentum_cut() -> void:
	var aim: Vector3 = player.get_aim_direction()
	var start: Vector3 = player.global_position
	var distance: float = _cut_distance_before_wall(start, aim)
	var end: Vector3 = start + aim * distance

	# Find every enemy close enough to the line from start to end.
	# (Untyped Array on purpose: an enemy could be freed while we wait below.)
	var targets: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null or enemy.is_dead:
			continue
		var reach: float = cfg.cut_half_width + enemy.hit_radius
		if _distance_to_line(enemy.global_position, start, end) <= reach:
			targets.append(enemy)

	player.meter.set_value(cfg.meter_after_cut)
	player.face_instantly(aim)
	_play_cut_animation()
	player.start_momentum_cut(aim, distance)
	var line_height: Vector3 = Vector3.UP * 1.0
	FX.cut_line(player.get_parent(), start + line_height, end + line_height, Color(0.55, 0.9, 1.0))

	# Wait until the dash reaches the end, THEN everything on the line is sliced at once.
	await player.cut_finished

	var hits: int = 0
	for item in targets:
		if not is_instance_valid(item):
			continue
		var enemy: EnemyBase = item as EnemyBase
		if enemy.is_dead:
			continue
		enemy.take_damage(cfg.cut_damage, aim * cfg.cut_knockback + Vector3.UP * 5.0)
		hits += 1

	player.camera_rig.add_shake(cfg.shake_cut if hits > 0 else cfg.shake_slash)
	if hits > 0:
		Game.hit_stop(cfg.hit_stop_cut)


## The cut is cut_distance long, but stops early in front of a wall.
func _cut_distance_before_wall(start: Vector3, direction: Vector3) -> float:
	var ray_start: Vector3 = start + Vector3.UP * 0.9
	var ray_end: Vector3 = ray_start + direction * cfg.cut_distance
	# Collision mask 1 = the "world" physics layer (floor, walls, pillars).
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return cfg.cut_distance
	var hit_position: Vector3 = hit["position"]
	return maxf(ray_start.distance_to(hit_position) - 0.6, 0.0)


## Top-down distance from a point to the line segment a-b
## (or INF if the point is far above/below the line).
func _distance_to_line(point: Vector3, a: Vector3, b: Vector3) -> float:
	if absf(point.y - a.y) > 2.5:
		return INF
	var p: Vector2 = Vector2(point.x, point.z)
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, a2, b2)
	return p.distance_to(closest)


# ---------------------------------------------------------------------------
# Sword animation (simple code tweens, no animation files)
# ---------------------------------------------------------------------------

func _play_swing_animation() -> void:
	var swing: float = deg_to_rad(swing_angle_degrees)
	if _sword_tween != null:
		_sword_tween.kill()
	# Start on one side, sweep fast to the other side, then return to rest.
	sword_pivot.rotation = Vector3(0.0, -swing * _swing_side, 0.0)
	_sword_tween = create_tween()
	_sword_tween.tween_property(sword_pivot, "rotation", Vector3(0.0, swing * _swing_side, 0.0), 0.08)
	_sword_tween.tween_interval(0.06)
	_sword_tween.tween_property(sword_pivot, "rotation", _rest_rotation(), 0.15)


func _play_cut_animation() -> void:
	if _sword_tween != null:
		_sword_tween.kill()
	# Hold the sword far out to the side during the dash, then return to rest.
	sword_pivot.rotation = Vector3(0.0, deg_to_rad(100.0), 0.0)
	_sword_tween = create_tween()
	_sword_tween.tween_interval(cfg.cut_duration + 0.15)
	_sword_tween.tween_property(sword_pivot, "rotation", _rest_rotation(), 0.2)


func _rest_rotation() -> Vector3:
	var d: Vector3 = rest_pose_degrees
	return Vector3(deg_to_rad(d.x), deg_to_rad(d.y), deg_to_rad(d.z))


## Flattened, normalized direction; `fallback` if the vector is (almost) zero.
func _flat_direction(vector: Vector3, fallback: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(vector.x, 0.0, vector.z)
	if flat.length() < 0.01:
		return fallback
	return flat.normalized()
