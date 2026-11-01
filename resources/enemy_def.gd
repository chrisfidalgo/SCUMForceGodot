class_name EnemyDef
extends Resource
## EnemyDef — one enemy TYPE, saved as a `.tres` (06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md §2).
##
## The enemy equivalent of CharacterDef. An enemy is three independent choices —
## when it wakes up, how it moves, how it attacks — plus its numbers. Every
## combination is a new `.tres`, never new code: a "patrolling guard that chases
## and swipes once it spots you" is PROXIMITY + PATROL→SEEK + MELEE.
##
## Things that differ per PLACEMENT rather than per type (which route a patroller
## walks, which way a turret faces, whether it stands on a platform) are exports
## on the Enemy node instead, so ten Turrets can share one file.
##
## The tuning panel edits this resource live, so retuning a slider retunes every
## enemy of the type at once — the same way AttackDef already behaves.
##
## THIS FILE IS A SHARED CONTRACT between packets P1h and P1i. Add fields if you
## must; do not rename or remove any.

## ALWAYS    — active from the moment it spawns.
## PROXIMITY — dormant until the player comes within `activation_range_px`.
enum Activation { ALWAYS, PROXIMITY }

## STATIONARY — never moves.
## WANDER     — random direction, changes every `wander_change_sec`, reverses off walls.
## PATROL     — walks its placement's route, waiting at each point.
## SEEK       — closes to `preferred_range_px`; backs off inside `retreat_ratio` of it.
enum Movement { STATIONARY, WANDER, PATROL, SEEK }

## NONE   — never attacks; contact damage only.
## MELEE  — swings when the player is within `attack_range_px` (its reach).
## RANGED — fires when the player is within `attack_range_px` (0 = any distance).
enum AttackStyle { NONE, MELEE, RANGED }

## AT_PLAYER    — aims where the player is when the attack begins (not tracked during wind-up).
## FIXED_FACING — fires along the placement's `facing_degrees`. A spatial puzzle, not pressure.
enum Aim { AT_PLAYER, FIXED_FACING }

## LOOP      — 1 → 2 → 3 → 1 …
## PING_PONG — 1 → 2 → 3 → 2 → 1 …
enum PatrolMode { LOOP, PING_PONG }

@export var display_name: String = ""
@export var placeholder_color: Color = Color(0.85, 0.7, 0.3)

@export_group("Health & contact")
@export var max_half_hearts: int = 2
## Damage dealt by walking into the player. Applies to every enemy, attacking or not.
@export var contact_damage_half_hearts: int = 1
## Minimum gap between contact hits on the same target.
@export var contact_cooldown_sec: float = 0.5

@export_group("Activation")
@export var activation: Activation = Activation.ALWAYS
## PROXIMITY only: how close the player must come to wake it.
@export var activation_range_px: float = 100.0
## PROXIMITY only: being hit wakes it regardless of distance.
@export var wake_on_damage: bool = true
## PROXIMITY only: if on, it goes dormant again when the player gets far enough away.
@export var leash_enabled: bool = false
## PROXIMITY + leash only: the distance at which it gives up. Keep above activation range.
@export var leash_range_px: float = 200.0

@export_group("Movement")
## How it moves while dormant. Ignored when activation is ALWAYS.
@export var idle_movement: Movement = Movement.STATIONARY
## How it moves once active.
@export var active_movement: Movement = Movement.STATIONARY
@export var move_speed: float = 40.0
## WANDER: seconds between direction changes.
@export var wander_change_sec: float = 1.5
## PATROL: route order.
@export var patrol_mode: PatrolMode = PatrolMode.LOOP
## PATROL: pause at each point.
@export var patrol_wait_sec: float = 0.5
## PATROL: how close counts as having arrived at a point.
@export var waypoint_reach_px: float = 4.0
## SEEK: the distance it tries to hold.
@export var preferred_range_px: float = 120.0
## SEEK: backs away when closer than preferred_range × this. 0 = never backs away.
@export_range(0.0, 1.0, 0.05) var retreat_ratio: float = 0.75

@export_group("Attack")
@export var attack_style: AttackStyle = AttackStyle.NONE
## The attack it fires, authored and tuned exactly like a player attack.
## MELEE uses a short-range AttackDef — a melee swing is a very short shot, so a
## low wall blocks it like any other LOW attack.
@export var attack: AttackDef
@export var aim: Aim = Aim.AT_PLAYER
@export var fire_cooldown_sec: float = 1.8
## Pause before the attack lands, with a visible tell. Direction locks when the
## wind-up starts, so the player can sidestep. 0 = instant.
@export var windup_sec: float = 0.0
## MELEE: the reach that triggers a swing. RANGED: max firing distance, 0 = any.
@export var attack_range_px: float = 0.0
## If off, it only attacks while standing still (SEEK holding range, STATIONARY,
## PATROL waiting). This is what makes the Seeker "close, then commit".
@export var fire_while_moving: bool = false
## How far from its centre the attack spawns.
@export var muzzle_offset_px: float = 10.0
