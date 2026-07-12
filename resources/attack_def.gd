class_name AttackDef
extends Resource
## AttackDef — one attack's tunable data (a custom Resource; edits live in the
## Inspector via its `.tres` file — no code). See docs/plan/04-COMBAT-MODEL.md.
##
## Attacks are aimed by the character's 8-way facing (there is no cursor); what
## makes them differ is the COMPOSITION below: a height behaviour, a lateral
## motion, how it treats walls, and an optional on-hit effect. The channel
## (which physics layers it can hit) is either the static `channel` for a
## ground shot, or DERIVED from the projectile's live height for a lob.

## How the projectile's height behaves over its flight.
##   GROUND     — stays at ground level (channel = `channel`, always LOW here).
##   LOB        — arcs up and back down over its range; its live channel follows
##                its height (ground→both→high→both→ground), so it lobs over low
##                walls at the top of the arc and lands to hit ground targets.
##   LOB_BOUNCE — (scaffold; used by a later character) a lob that bounces.
enum HeightProfile { GROUND, LOB, LOB_BOUNCE }

## Lateral wiggle applied perpendicular to travel.
##   STRAIGHT — none.
##   SINE     — a sine-wave weave (widens a ground shot's chance to clip enemies).
enum LateralMotion { STRAIGHT, SINE }

## What happens when the projectile meets a wall it can't pass.
##   STOP    — it's absorbed (default).
##   REFLECT — (scaffold; used by a later character) bounces off at the incidence angle.
enum WallBehavior { STOP, REFLECT }

## Which collision channel a GROUND shot occupies. LOB shots ignore this and
## derive their channel from height instead. (LOW = ground, HIGH = elevated,
## BOTH = either — see 02-ARCHITECTURE.md §4.)
enum Channel { LOW, HIGH, BOTH }

@export_group("Shape")
@export var height_profile: HeightProfile = HeightProfile.GROUND
## LOB/LOB_BOUNCE only: peak height of the arc (elevation units). Must exceed the
## HIGH threshold (ChannelMasks.HEIGHT_HIGH_MIN) for the arc to clear low walls.
@export var lob_peak_height: float = 20.0
@export var lateral_motion: LateralMotion = LateralMotion.STRAIGHT
## SINE only: how far the weave pushes sideways, and its wavelength in pixels.
@export var sine_amplitude_px: float = 4.0
@export var sine_wavelength_px: float = 40.0
@export var wall_behavior: WallBehavior = WallBehavior.STOP
## GROUND shots only: the fixed channel. (LOB derives channel from height.)
@export var channel: Channel = Channel.LOW

@export_group("Impact")
@export var damage_half_hearts: int = 1
## Spawned at the hit point (slow field, quake, etc.). Empty = plain damage.
@export var on_hit_effect: PackedScene

@export_group("Timing & reach")
@export var cooldown_sec: float = 0.25
@export var projectile_speed: float = 320.0
@export var range_px: float = 240.0
## The projectile scene; empty falls back to the spawner's default projectile.
@export var projectile_scene: PackedScene
