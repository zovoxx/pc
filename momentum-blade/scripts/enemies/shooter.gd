class_name Shooter
extends EnemyBase
## Shooter: keeps its distance and fires a slow glowing orb every 2 seconds.
## The orb on its front swells up just before each shot, so you see it coming.
## The orbs are slow: run sideways, dash through them, or slash them out of the air.

## The projectile scene this enemy fires.
@export var projectile_scene: PackedScene

var _fire_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0

@onready var muzzle: Marker3D = $Visual/Muzzle
@onready var orb: MeshInstance3D = $Visual/Orb


func _ready() -> void:
	super._ready()  # run EnemyBase's _ready() first
	# Random first shot time, so a group of shooters doesn't fire all at once.
	_fire_timer = cfg.shooter_fire_interval * randf_range(0.6, 1.2)
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0


func _get_max_health() -> float:
	return cfg.shooter_health


func _think(delta: float) -> Vector3:
	face_towards(player.global_position, delta, 8.0)
	_update_shooting(delta)
	return _choose_movement(delta)


func _update_shooting(delta: float) -> void:
	_fire_timer -= delta
	# Charge-up warning: the orb grows during the last moments before firing.
	var charge: float = 1.0 - clampf(_fire_timer / cfg.shooter_charge_time, 0.0, 1.0)
	orb.scale = Vector3.ONE * (0.5 + charge * 0.9)
	if _fire_timer <= 0.0:
		_fire()
		_fire_timer = cfg.shooter_fire_interval


func _fire() -> void:
	if projectile_scene == null:
		return
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	get_parent().add_child(projectile)
	projectile.global_position = muzzle.global_position
	# Aim at the player's chest, where they are right now (no leading the target).
	var target: Vector3 = player.global_position + Vector3.UP * 1.0
	projectile.launch((target - projectile.global_position).normalized() * cfg.projectile_speed)


func _choose_movement(delta: float) -> Vector3:
	var to_player: Vector3 = flat_offset_to_player()
	var distance: float = to_player.length()
	var toward: Vector3 = to_player.normalized()

	# Switch strafe direction now and then, so it's less predictable.
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.5, 3.0)
		_strafe_sign = -_strafe_sign

	if distance < cfg.shooter_preferred_distance - 2.0:
		return -toward * cfg.shooter_move_speed  # too close: back away
	if distance > cfg.shooter_preferred_distance + 2.0:
		return toward * cfg.shooter_move_speed  # too far: come closer
	# At a good distance: strafe sideways.
	var sideways: Vector3 = toward.cross(Vector3.UP) * _strafe_sign
	return sideways * cfg.shooter_move_speed * 0.6
