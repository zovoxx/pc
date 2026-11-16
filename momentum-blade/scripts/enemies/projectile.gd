class_name Projectile
extends Area3D
## A slow glowing orb fired by Shooters.
## It hurts the player on touch and pops when it hits a wall or the floor.
## It flies straight through a dashing (invincible) player, and the sword can
## destroy it.

var velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0


func _ready() -> void:
	add_to_group("projectiles")
	_life = Game.config.projectile_lifetime
	body_entered.connect(_on_body_entered)


## Sets the orb flying with this velocity.
func launch(new_velocity: Vector3) -> void:
	velocity = new_velocity


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var hit_player: Player = body as Player
	if hit_player != null:
		# take_hit() returns false if the player was invincible (dashing):
		# then the orb keeps flying.
		if hit_player.take_hit(global_position):
			pop()
	else:
		pop()  # hit the arena


## Destroys the orb with a little burst.
func pop() -> void:
	if is_queued_for_deletion():
		return
	FX.burst(get_parent(), global_position, Color(1.0, 0.45, 0.8), 10, 5.0, 0.1)
	queue_free()
