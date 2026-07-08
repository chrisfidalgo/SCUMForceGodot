class_name AttackDef
extends Resource
## AttackDef — one attack's tunable data (a custom Resource).
##
## A Resource is a Godot data asset saved as a `.tres` file; every @export field
## below shows up as an editable row in the Inspector. This is where the owner
## tunes attacks — no code editing. New attack = new .tres file, no new script.
##
## The channel/aim split is the game's identity (02-ARCHITECTURE.md §4):
## `channel` decides which hurt/block physics layers a projectile interacts
## with; `aim_type` decides how the player aims it.

## How the attack is aimed.
##   FIXED          — ignores the cursor; a self-defined pattern (e.g. radial burst).
##   FORWARD_VECTOR — fires straight along the character's facing.
##   FREE_CONE      — fires toward the cursor, clamped to `cone_degrees` around facing.
enum AimType { FIXED, FORWARD_VECTOR, FREE_CONE }

## Which collision channel the attack occupies.
##   LOW  — ground-level; stopped by low blockers; can't reach elevated targets.
##   HIGH — lobs over low walls; reaches elevated targets; misses pure-ground ones.
##   BOTH — reaches every elevation, but the first blocker of either channel stops it.
enum Channel { LOW, HIGH, BOTH }

@export var aim_type: AimType = AimType.FORWARD_VECTOR
## FREE_CONE only: cursor aim is clamped to this arc (degrees) around facing.
@export var cone_degrees: float = 90.0
@export var channel: Channel = Channel.LOW
@export var damage_half_hearts: int = 1
@export var cooldown_sec: float = 0.25
## The projectile scene to spawn, or empty for melee / self-centered bursts.
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 320.0
## Travel distance for projectiles; for a FIXED radial burst this is the radius.
@export var range_px: float = 240.0
