class_name EnemyBase
extends CharacterBody3D
## Shared code for every enemy type:
##   health, taking damage (white flash + knockback), dying, gravity,
##   a short "spawn-in" moment, and turning to face the player.
## Each enemy type (grunt.gd, shooter.gd) extends this script and adds its own
## behaviour by overriding _think(), _get_max_health() and _on_damaged().

## Emitted once when this enemy dies. The wave spawner listens to it.
signal died(enemy: EnemyBase)

# One plain white material, shared by all enemies, used for the hit flash.
static var _flash_material: StandardMaterial3D

## How "wide" the enemy is for sword hit checks (meters).
@export var hit_radius: float = 0.5
## Colour of the burst when this enemy dies.
@export var death_color: Color = Color(1.0, 0.4, 0.3)

## The player to chase. Set by the wave spawner when the enemy is created.
var player: Player
var health: float = 1.0
var is_dead: bool = false

var _knockback: Vector3 = Vector3.ZERO
var _flash_time: float = 0.0
var _spawn_time: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _scale_tween: Tween

@onready var cfg: GameConfig = Game.config
@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("enemies")
	health = _get_max_health()
	# Remember all meshes of the model, so we can flash them all white.
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node as MeshInstance3D)
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color.WHITE

	# Spawn-in: pop up from nothing. The enemy is frozen and harmless until done.
	_spawn_time = cfg.enemy_spawn_time
	visual.scale = Vector3.ONE * 0.01
	_scale_tween = create_tween()
	_scale_tween.tween_property(visual, "scale", Vector3.ONE, cfg.enemy_spawn_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Override these in each enemy type
# ---------------------------------------------------------------------------

func _get_max_health() -> float:
	return 1.0


## Decide what to do this frame and return the horizontal velocity the enemy
## wants. Only called while the player is alive and the enemy finished spawning.
func _think(_delta: float) -> Vector3:
	return Vector3.ZERO


## React to being hit but not killed (e.g. flinch).
func _on_damaged() -> void:
	pass


# ---------------------------------------------------------------------------
# Shared behaviour
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y -= cfg.gravity * delta

	var wanted: Vector3 = Vector3.ZERO
	if _spawn_time > 0.0:
		_spawn_time -= delta
	elif player != null and player.is_alive():
		wanted = _think(delta)

	# Knockback is added on top of normal movement and fades out quickly.
	_knockback = _knockback.move_toward(Vector3.ZERO, cfg.enemy_knockback_decay * delta)
	velocity.x = wanted.x + _knockback.x
	velocity.z = wanted.z + _knockback.z
	move_and_slide()


func _process(delta: float) -> void:
	# End the white hit-flash after a moment. (During a hit-stop delta is 0,
	# so the flash holds for the whole freeze, which looks great.)
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_set_flash(false)


## Called by the player's sword. `knockback` is a velocity (its Y pops the enemy up).
func take_damage(amount: float, knockback: Vector3) -> void:
	if is_dead:
		return
	health -= amount
	_knockback = Vector3(knockback.x, 0.0, knockback.z)
	if knockback.y > 0.0:
		velocity.y = knockback.y
	_flash_time = cfg.enemy_flash_time
	_set_flash(true)
	FX.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.95, 0.8), 8, 7.0, 0.1)
	if health <= 0.0:
		_die()
	else:
		_on_damaged()


func _set_flash(on: bool) -> void:
	for mesh in _meshes:
		mesh.material_overlay = _flash_material if on else null


func _die() -> void:
	is_dead = true
	remove_from_group("enemies")
	$CollisionShape3D.set_deferred("disabled", true)
	died.emit(self)
	FX.burst(get_parent(), global_position + Vector3.UP, death_color, 26, 9.0, 0.2)
	# Pop bigger for a moment, then shrink away and delete ourselves.
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(visual, "scale", Vector3.ONE * 1.35, 0.07)
	_scale_tween.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.15)
	_scale_tween.tween_callback(queue_free)


## Smoothly turns the model toward a point.
func face_towards(target: Vector3, delta: float, turn_speed: float) -> void:
	var offset: Vector3 = target - global_position
	if Vector2(offset.x, offset.z).length() < 0.01:
		return
	var target_yaw: float = atan2(-offset.x, -offset.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Flat direction the model is facing.
func get_facing() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, visual.rotation.y)


## Flat (top-down) vector from this enemy to the player.
func flat_offset_to_player() -> Vector3:
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0.0
	return offset
