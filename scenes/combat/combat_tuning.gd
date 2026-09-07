class_name CombatTuning
extends RefCounted
## CombatTuning — global combat values that the in-play tuning panel edits live.
##
## These are `static var`s (one shared copy, reachable as CombatTuning.xxx) so a
## running projectile reads the latest value every frame and the debug tuning
## panel (scenes/ui/tuning_panel) can nudge them mid-play without dropping out of
## the game. Per-attack numbers (range, speed, damage…) live on each AttackDef
## instead; these are the cross-cutting projectile/height knobs.

## Ground shadow under a projectile.
static var shadow_base_radius := 7.0        ## x-radius at height 0
static var shadow_shrink_per_unit := 0.04   ## how fast it shrinks with height
static var shadow_alpha := 0.5              ## opacity at height 0

## How much a projectile's sprite grows per unit of height (sells elevation).
static var height_scale_per_unit := 0.02

## Cosmetic TP-style trailing sprite.
static var tail_gap_px := 5.0               ## how far it trails behind the head
static var tail_fps := 12.0                 ## trail animation speed

## Height → channel thresholds (elevation units). Below ground_max = LOW, at or
## above high_min = HIGH, in between = BOTH. Widening the HIGH band makes lobs
## clear walls more readily. Read by ChannelMasks.channel_for_height().
static var height_ground_max := 3.0
static var height_high_min := 10.0
