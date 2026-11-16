# Momentum Blade (prototype)

**Your speed is your damage.** Chain dashes, slides, wall-runs and wall-jumps to fill
the speed meter. The fuller it is, the harder your sword hits. At max speed your next
click is the **Momentum Cut**: a 10 m dash that slices every enemy on the line.
Standing still drains the meter fast, and getting hit empties it.

Made with Godot 4 (4.3 or newer) and typed GDScript. Placeholder art only (boxes and capsules).

## How to play it (Ubuntu)

1. Open Godot 4.
2. In the Project Manager click **Import**, pick `momentum-blade/project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ Play button at the top right).

On the very first import Godot builds its class list. If you see red "Could not find type ..."
errors in the Output panel, use **Project > Reload Current Project** once. They go away.

### Controls

| Key | Action |
|---|---|
| W A S D (or arrows) | Move (relative to the camera) |
| Mouse | Turn the camera / aim |
| Space | Jump (tap = short hop) |
| Shift | Dash: fast burst, invincible for 0.2 s |
| Ctrl (or C) | Slide: low and fast, keeps momentum, goes under grunt swings |
| Left click | Slash. With a full meter: **Momentum Cut** |
| Esc | Pause (click to resume) |
| R | Restart after dying |

**Wall-run:** jump at a wall at an angle while holding a direction, and you'll run along it.
Press Space to jump off. The teal walls are placed for wall-running; the two long
parallel ones in the middle let you chain wall-jumps back and forth.

**Combos that keep speed:** dash → slide, dash → jump, slide → jump, wall-jump → dash.

## How the speed meter works

| Action | Meter |
|---|---|
| Dash | +15 |
| Slide | +10 |
| Wall-run | +5 per second |
| Wall-jump | +15 |
| Slash hits an enemy | +5 per enemy |
| Running normally | drains slowly |
| Standing still | drains fast |
| Getting hit | back to 0 |

Damage multiplier: 0-33 = **x1**, 34-66 = **x2**, 67-99 = **x3**. At 100 the bar pulses and
your next click is the Momentum Cut (the meter then drops to 50).

Enemies: the red **Grunt** (3 HP) walks up and leans back with a "!" for 0.5 s before
swinging its club. Dash through it, slide under it, jump over it, or step back. The purple
**Shooter** (2 HP) keeps its distance and fires a slow orb every 2 s. The orb swells
before each shot, and you can slash orbs out of the air.

## Tweaking the game (no code needed)

Every tuning number is in **one file**: `config/game_config.tres`.
Double-click it in Godot's FileSystem dock and the Inspector shows all values, grouped
(Movement, Dash, Slide, Wall Run, Speed Meter, Damage Tiers, Sword Slash, Momentum Cut,
Game Feel, Grunt, Shooter, Waves...). Hover over any value to see what it does.
To undo a change, click the ↺ revert arrow next to it.

A few visual settings live on the nodes themselves. Open the scene, select the node and look
in the Inspector: camera pitch limits on `CameraRig` and sword pose on `Combat` (both in
`scenes/player.tscn`), HUD colours on the root of `scenes/hud.tscn`.

## How the code is organized

```
momentum-blade/
├── project.godot            Project settings, input map, physics layer names
├── config/
│   ├── game_config.gd       Declares every tuning value (with descriptions)
│   └── game_config.tres     The values themselves: edit this in the Inspector
├── scenes/
│   ├── main.tscn            The game: lights, sky, arena, player, spawner, HUD
│   ├── arena.tscn           40x40 m arena made of CSG boxes (with collision)
│   ├── player.tscn          Player body, sword, camera rig
│   ├── grunt.tscn / shooter.tscn / projectile.tscn
│   └── hud.tscn             Speed bar, health, wave number, messages
├── scripts/
│   ├── game.gd              Autoload "Game": gives access to the config + hit-stop
│   ├── main.gd              Wires everything together, pause, game over, restart
│   ├── player/
│   │   ├── player.gd        Movement state machine + health
│   │   ├── speed_meter.gd   The 0-100 meter, tiers and damage multiplier
│   │   ├── player_combat.gd Slash and Momentum Cut
│   │   └── player_camera.gd Mouse look, camera shake, FOV
│   ├── enemies/
│   │   ├── enemy_base.gd    Shared enemy code (health, hit flash, knockback, death)
│   │   ├── grunt.gd         Chase, wind-up, swing
│   │   ├── shooter.gd       Keep distance, charge, fire
│   │   └── projectile.gd    The shooter's orb
│   ├── world/wave_spawner.gd  Endless waves (4, 6, 8, ...)
│   ├── ui/hud.gd            Updates the HUD
│   └── fx/                  Visual effects made in code (slash swoosh, sparks, afterimages)
└── materials/grid.gdshader  Grid pattern on the floor and walls (helps you feel speed)
```

A good reading order: `speed_meter.gd` → `player.gd` → `player_combat.gd` →
`enemy_base.gd` → `grunt.gd`.

**The player is a "state machine".** It is always in exactly one state (NORMAL, DASH, SLIDE,
WALL_RUN, CUT or DEAD). Each state has its own `_process_...()` function that decides
the velocity for this frame, and `_start_...()` functions switch between states.

**Physics layers:** 1 = world, 2 = player, 3 = enemies, 4 = projectiles. The player only
collides with the world, so you can dash through enemies.

## Things to test

1. **Meter basics.** Stand still after gaining some meter and watch it drain fast. Run
   around and it drains slowly.
2. **Pure movement to max.** Use only dashes and wall-runs (try the two teal walls in the
   middle) to reach 100. The FOV should widen as it fills and the bar should pulse at full.
3. **Momentum Cut.** At full meter, line up several grunts and click. You should zoom ~10 m,
   see a glowing slice, get a long freeze-frame with a big shake, and every grunt on the
   line should explode. The meter should drop to 50.
4. **Tiers.** Hit a grunt at x1 (needs 3 slashes), then at x3 (1 slash kills).
5. **Dodging the grunt.** Wait for the lean-back + "!" and then slide under the swing, dash
   through it, and jump over it. Each should avoid the hit.
6. **Shooter orbs.** Dash through an orb (no damage) and slash one out of the air.
7. **Getting hit.** The meter goes to 0, the screen flashes red, you blink for 1 s and can't
   be hit again during it.
8. **Waves and death.** Clear a wave and the next starts 3 s later with 2 more enemies.
   Die, check that the wave number is shown, then press R.

## The 5 tuning values most worth playing with

1. **Speed Meter → `drain_idle` / `drain_moving`**: how harshly the game punishes slowing
   down. This decides the whole pacing.
2. **Dash → `dash_cooldown`** (and `gain_dash`): dash-spam is the easiest way to build
   meter. Raise the cooldown to push players toward wall-runs and slides.
3. **Momentum Cut → `cut_half_width`**: how forgiving the cut's line is. Wider = easier
   multi-kills.
4. **Grunt → `grunt_windup_time`**: the reaction window. 0.5 s is fair; 0.35 s gets intense.
5. **Game Feel → `hit_stop_slash` / `hit_stop_cut`**: the "weight" of hits. Try 0.08 / 0.25
   to feel the difference, or 0 to see how much it adds.

## Making a stand-alone Linux build (optional)

**Editor → Manage Export Templates → Download and Install**, then
**Project → Export → Add... → Linux**, then **Export Project**. You get an executable you
can run without the editor.
