# Koopa port

`assets/koopa.gd` replaces the old Node3D/raycast controller with a
CharacterBody3D state machine. `assets/koopa.tscn` is a normal, shelled Koopa;
its old `race_mode = true` override was the cause of the immediate corner run.
The battlefield instance no longer overrides obsolete movement properties.

## Decomp sources audited

Reference checkout: `/home/lfsuser/sm64`, commit `9921382`.

- `src/game/behaviors/koopa.inc.c`: normal/tiny/unshelled states, attack table,
  shell diving and reclaim, both Koopa the Quick races, and race endpoint rules.
- `src/game/obj_behaviors_2.c`: home-distance substitution, wall/edge/object
  turning, knockback, squishing, and blue-coin loot.
- `src/game/object_helpers.c`: waypoint-plane crossing (`cur_obj_follow_path`)
  and standard object motion.
- `src/game/interaction.c`: Koopa's bounce-top attack dispatch and shell riding.
- `src/game/behaviors/koopa_shell.inc.c`: idle shell physics, riding ownership,
  and disposal after dismount.
- `data/behavior_data.c`: initial gravity, wall radius, home, and movement type.
- `levels/{bob,thi}/areas/1/trajectory.inc.c`: both original race paths.

Movement speed is stored in N64 units per 30 Hz frame, converted to Godot units
per second only at the physics boundary. Turn increments, countdowns, gravity,
slide deceleration, and animation durations use the same 30 Hz time base.
Race points use the terrain converter's `(-z, y, x) / LibSM64.scale_factor`.
Custom `race_path` points are already Godot world positions.

Normal Koopas walk at 3 N64 units/frame. The authentic shelled flee speed is 17,
not a replacement low-speed workaround. Fleeing turns away from Mario, stops
when Mario is far away, and returns toward home outside the home radius.
Shellless Koopas slide after being attacked, get up, avoid Mario, seek the
nearest available shell, and dive to recover it. Lost shells cause wandering,
not a chase after Mario. Reclaim is atomic, checks the swept dive trajectory
and obstruction, excludes ridden/deleted shells, and gives nearby Mario priority.
Rendering yaw is separate from movement yaw.

Popped shells receive a random horizontal velocity (`shell_pop_force`, default
6 Godot units/second) and upward velocity (`shell_pop_up_speed`, default 3).
The MeshInstance3D shell moves by scripted transform updates, with no Godot
bodies, collision shapes, or skeleton rig. The static visual preserves the
imported rest pose without Godot generating a PhysicalBoneSimulator3D.
It bounces, settles, remains rideable while moving,
and does not expire after stopping. This launch impulse is a requested variation from the original game.

Stomp bounce velocity uses the extension's world-units/second API: the decomp's
30 units/frame converts to 9 at the project's scale and tick rate. Stomps enter
freefall, clear variable-jump-height state, and preserve horizontal velocity,
giving a consistent 1.28-unit rise even after a long jump or while holding A.

Non-attacking side contact gives Mario backward knockback without damage or
displacing Koopa. Ground contact uses soft knockback; airborne contact uses
air knockback. A contact cooldown prevents repeated overlap from restarting
the recoil. Stomps and other attacks keep their existing priority.

`assets/coin.tscn` has a Coin3D root (the previous wrapper root caused the spawn
cast to fail). Squishing spawns it directly under the running scene with hitbox
`(2, 2.327, 2)`, blue enabled, yellow/red disabled, moving enabled, and value 5.
Its sprite starts above terrain and becomes collectible on its first descent.
Moving coins use scaled launch velocities and the libsm64 collision layer.

## Collision integration

Godot group membership does not create a physics collider. The existing
libsm64 static/dynamic surface handlers now maintain hidden internal Godot
triangle colliders on layer **32**, reserved for libsm64 object queries.
Koopa uses layer 1 plus this layer. Registration, movement, unloading, and
removal keep the two collision worlds synchronized. Dynamic proxy transforms
match the position/rotation passed to libsm64 (the existing native handler does
not apply node scale). Static proxies use the original full transform.

Bob-omb Battlefield installs its static terrain directly from decomp data,
overwriting the normal static handler's surfaces. Its generated terrain mesh
therefore also registers an object collider explicitly.

Shell meshes stay in `libsm64_surface_objects`. Their `libsm64_mesh_only`
metadata prevents the surface bridge from creating Godot bodies, including on
reload. Scripted movement updates the native surfaces after moving the mesh.
Koopa handles loose-shell contact with a swept radius check; shellless dives
can reach the center for reclaim. Terrain still blocks movement and reclaim.
Riding/reclaim unloads the native surfaces. A riding action cannot capture
every other loose shell.

## Koopa the Quick integration

`race_mode` selects a separate lifecycle and waits for `start_race()`; it does
not start automatically. The controller includes the 50-frame start delay,
walk-start acceleration, slope-dependent speed, wall climbs, edge jumps,
bowling-ball avoidance, waypoint crossing, endpoint result, and final stop.
Bowling balls can join `bowling_balls` and expose a Godot-units/second `velocity`.

The project has no race dialogue UI. The controller exposes integration hooks:

- `race_requested(dialog_id)` -> call `start_race()` or `decline_race()`.
- `race_started` / `race_finished` -> race timer and UI.
- `race_result(dialog_id)` -> original win/loss/cannon-cheat dialogue ID.
- `acknowledge_race_result()` -> one `race_star_requested(world_position)` on a win.

These signals do not themselves display a dialogue, freeze the whole level,
play race music, or instantiate a star. Those presentation hooks are separate
from the tested controller. Native dust/sparkle particles and blinking are also
not reproduced. This is a Godot port, not a bit-exact SM64 simulation.

## Regression test

From this project directory, using a Godot 4.8 build with the bundled extension:

```sh
godot --headless --path . --audio-driver Dummy --fixed-fps 60 tests/koopa_regression.tscn
```

The test uses the project's local ROM and actual libsm64 handlers/Mario API.
It covers normal scene defaults, home range and flee termination, mesh-only
floor/wall/shell collision, moving and unloaded surfaces, shell recovery and
ownership, stomp/punch/dismount interactions, race waiting/countdown/completion,
coordinate conversion, and the serialized battlefield Koopa on actual terrain.
It also exercises coin creation, launch, collision, collection, lifetime after
Koopa is freed, random shell impulses, and native Mario apex heights for four
incoming air actions with A both held and released.
It exits nonzero on a failed assertion. Visual playtesting is still separate
from these headless checks.
