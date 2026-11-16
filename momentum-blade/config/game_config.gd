class_name GameConfig
extends Resource
## Every tuning number in the game lives here, in one place.
##
## HOW TO TWEAK: in Godot's FileSystem dock, double-click
## res://config/game_config.tres. All of these values appear in the Inspector,
## grouped by topic. Hover a value to see what it does.
## The numbers written below are only the defaults; your edits are saved in
## game_config.tres. (Right-click a value > "Revert" to go back to the default.)


@export_group("Movement")
## Top speed when simply running (meters per second).
@export var run_speed: float = 9.0
## How quickly you reach run speed on the ground. Higher = snappier.
@export var ground_acceleration: float = 90.0
## How quickly you stop on the ground when you let go of the keys.
@export var ground_friction: float = 70.0
## How strongly you can steer while in the air.
@export var air_acceleration: float = 35.0
## How quickly you slow down in the air when not pressing any key.
@export var air_drag: float = 4.0
## When you go faster than run speed (after a dash, slide or wall-jump), how fast
## that extra speed bleeds away on the ground. Lower = keep momentum longer.
@export var overspeed_decel_ground: float = 22.0
## Same as above, but while in the air.
@export var overspeed_decel_air: float = 6.0
## How fast the character model turns to face where it's going.
@export var turn_speed: float = 14.0
## Seconds a key press is remembered if it was slightly too early
## (jump before landing, slide before landing, click before the sword is ready).
@export var input_buffer_time: float = 0.12


@export_group("Jump & Gravity")
## Upward speed of a normal jump.
@export var jump_velocity: float = 10.0
## Gravity. Higher than real life (9.8) makes jumps feel less floaty.
@export var gravity: float = 30.0
## Extra gravity while falling, for snappier jumps.
@export var fall_gravity_multiplier: float = 1.5
## Fastest you can fall.
@export var max_fall_speed: float = 40.0
## Letting go of Space early multiplies your upward speed by this (short hops).
@export_range(0.0, 1.0) var jump_release_damping: float = 0.5
## Grace time after running off a ledge during which you can still jump.
@export var coyote_time: float = 0.1


@export_group("Dash")
## Speed during a dash.
@export var dash_speed: float = 28.0
## How long a dash lasts (seconds). Distance = speed x duration.
@export var dash_duration: float = 0.16
## Speed you keep right after a dash ends.
@export var dash_exit_speed: float = 14.0
## Seconds before you can dash again.
@export var dash_cooldown: float = 0.45
## Seconds of invincibility when a dash starts.
@export var dash_invincibility: float = 0.2
## Dashes allowed per jump (refilled when you land or start a wall-run).
@export var air_dashes: int = 1


@export_group("Slide")
## Slide speed. If you're already faster (e.g. right after a dash) you keep that speed.
@export var slide_speed: float = 16.0
## Upper limit for slide speed.
@export var slide_max_speed: float = 30.0
## Longest a slide lasts (seconds).
@export var slide_duration: float = 0.65
## How quickly a slide slows down (speed lost per second).
@export var slide_friction: float = 9.0
## Seconds before you can slide again.
@export var slide_cooldown: float = 0.35
## How much you can steer during a slide (radians per second).
@export var slide_steer: float = 2.0
## Body height while sliding (standing is 1.8). Below the grunt swing height = you slide under it.
@export_range(0.8, 1.8) var slide_height: float = 0.9


@export_group("Wall Run")
## Minimum speed along the wall while wall-running.
@export var wall_run_speed: float = 13.0
## Longest a single wall-run can last (seconds).
@export var wall_run_max_time: float = 1.3
## Gravity while wall-running (much weaker than normal).
@export var wall_run_gravity: float = 6.0
## Small upward pop when you grab a wall.
@export var wall_run_start_lift: float = 2.5
## You must be moving at least this fast ALONG the wall to start a wall-run.
@export var wall_run_min_speed: float = 4.0
## Upward speed of a wall-jump.
@export var wall_jump_up: float = 10.0
## How hard a wall-jump pushes you away from the wall.
@export var wall_jump_push: float = 10.0
## For this long after a wall-jump, steering can't cancel the jump's sideways
## push, so you reach the opposite wall even while holding W.
@export var wall_jump_momentum_time: float = 0.45


@export_group("Speed Meter")
## The meter goes from 0 to this.
@export var meter_max: float = 100.0
## Meter gained per dash.
@export var gain_dash: float = 15.0
## Meter gained per slide.
@export var gain_slide: float = 10.0
## Meter gained per second of wall-running.
@export var gain_wall_run_per_second: float = 5.0
## Meter gained per wall-jump.
@export var gain_wall_jump: float = 15.0
## Meter gained for each enemy a slash hits.
@export var gain_enemy_hit: float = 5.0
## Drain per second while moving normally (running, jumping).
@export var drain_moving: float = 4.0
## Drain per second while standing still.
@export var drain_idle: float = 30.0
## Below this speed (m/s) you count as "standing still".
@export var idle_speed_threshold: float = 1.5
## If on, a full meter stays full until you use the Momentum Cut or get hit.
@export var hold_full_meter: bool = true


@export_group("Damage Tiers")
## Base damage of one slash (before the multiplier).
@export var slash_damage: float = 1.0
## Meter value where tier 2 starts.
@export var tier_2_threshold: float = 34.0
## Meter value where tier 3 starts.
@export var tier_3_threshold: float = 67.0
## Damage multiplier for each tier.
@export var tier_1_multiplier: float = 1.0
@export var tier_2_multiplier: float = 2.0
@export var tier_3_multiplier: float = 3.0


@export_group("Sword Slash")
## Seconds between slashes.
@export var slash_cooldown: float = 0.28
## How far the slash reaches (meters from the player).
@export var slash_range: float = 2.6
## Width of the slash arc in degrees.
@export var slash_arc_degrees: float = 140.0
## Knockback speed given to enemies hit by a slash.
@export var slash_knockback: float = 9.0


@export_group("Momentum Cut")
## How far the cut dashes you forward (meters). Stops early at walls.
@export var cut_distance: float = 10.0
## How long the cut's dash takes (seconds). Shorter = faster.
@export var cut_duration: float = 0.14
## Damage dealt to every enemy on the line.
@export var cut_damage: float = 10.0
## Enemies this close to the cutting line (meters) get hit.
@export var cut_half_width: float = 1.4
## Knockback speed given to enemies hit by the cut.
@export var cut_knockback: float = 12.0
## The meter is set to this after a Momentum Cut.
@export var meter_after_cut: float = 50.0


@export_group("Player Health")
## Hits you can take.
@export var max_health: int = 5
## Invincibility after being hit (seconds).
@export var hurt_invincibility: float = 1.0
## How hard you get pushed back when hit.
@export var hurt_knockback: float = 9.0


@export_group("Game Feel")
## Freeze-frame length when a slash lands (seconds).
@export var hit_stop_slash: float = 0.05
## Freeze-frame length when a Momentum Cut lands (seconds).
@export var hit_stop_cut: float = 0.15
## Freeze-frame length when you get hit (seconds). 0 = off.
@export var hit_stop_hurt: float = 0.08
## Camera shake strength (0 to 1) when a slash lands.
@export_range(0.0, 1.0) var shake_slash: float = 0.3
## Camera shake strength (0 to 1) for a Momentum Cut.
@export_range(0.0, 1.0) var shake_cut: float = 0.9
## Camera shake strength (0 to 1) when you get hit.
@export_range(0.0, 1.0) var shake_hurt: float = 0.6
## How fast camera shake fades out (per second).
@export var shake_decay: float = 2.5
## Largest camera offset (meters) at full shake.
@export var shake_max_offset: float = 0.35
## Camera field of view (degrees) with an empty meter.
@export var base_fov: float = 72.0
## Extra field of view at a full meter. The camera widens as the meter fills.
@export var fov_bonus_at_full: float = 18.0
## How long enemies flash white when hit (seconds).
@export var enemy_flash_time: float = 0.1
## Mouse look sensitivity.
@export var mouse_sensitivity: float = 0.0025


@export_group("Enemies (shared)")
## How quickly knockback wears off.
@export var enemy_knockback_decay: float = 30.0
## Spawn-in time during which a new enemy is frozen and harmless.
@export var enemy_spawn_time: float = 0.8
## Short pause when a walking enemy gets hit.
@export var enemy_stagger_time: float = 0.25


@export_group("Grunt")
## Grunt hit points.
@export var grunt_health: float = 3.0
## Grunt walking speed.
@export var grunt_move_speed: float = 4.5
## The grunt starts its wind-up when you're this close.
@export var grunt_attack_range: float = 2.2
## The clear "lean back" warning before the swing (seconds).
@export var grunt_windup_time: float = 0.5
## How far the swing reaches.
@export var grunt_swing_reach: float = 3.0
## How wide the swing is (degrees).
@export var grunt_swing_arc_degrees: float = 150.0
## Height of the swing above the ground. Slide under it or jump over it!
@export var grunt_swing_height: float = 1.15
## Little forward lunge during the swing.
@export var grunt_lunge_speed: float = 6.0
## Pause after swinging: your chance to punish it.
@export var grunt_recover_time: float = 0.8


@export_group("Shooter")
## Shooter hit points.
@export var shooter_health: float = 2.0
## Shooter walking speed.
@export var shooter_move_speed: float = 3.5
## The shooter tries to stay about this far from you.
@export var shooter_preferred_distance: float = 12.0
## Seconds between shots.
@export var shooter_fire_interval: float = 2.0
## Visible charge-up before each shot (seconds, part of the interval).
@export var shooter_charge_time: float = 0.6
## Projectile speed. Slow = easy to dodge.
@export var projectile_speed: float = 9.0
## Projectiles disappear after this many seconds.
@export var projectile_lifetime: float = 6.0


@export_group("Waves")
## Enemies in the first wave.
@export var first_wave_size: int = 4
## Extra enemies added every wave.
@export var wave_size_increase: int = 2
## Seconds before the very first wave.
@export var first_wave_delay: float = 1.5
## Seconds between the last enemy dying and the next wave starting.
@export var time_between_waves: float = 3.0
## Fraction of each wave that are Shooters (the rest are Grunts).
@export_range(0.0, 1.0) var shooter_fraction: float = 0.3
## Enemies only spawn at spawn points at least this far from you.
@export var spawn_min_distance: float = 10.0
