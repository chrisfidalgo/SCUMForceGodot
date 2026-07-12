class_name ChannelMasks
extends RefCounted
## ChannelMasks — turns an AttackDef.Channel into an Area2D collision_mask.
##
## This is the single place the channel identity (02-ARCHITECTURE.md §4)
## becomes an actual physics bitmask. A `collision_mask` is which physics
## layers a node can *detect*; the physics layer numbers below match the
## frozen names in Project Settings -> Layer Names -> 2D Physics.
##
##   LOW  -> hurt_low + block_low
##   HIGH -> hurt_high + block_high   (deliberately NOT block_low, so HIGH
##                                     shots lob over low walls)
##   BOTH -> all four — stopped by whichever blocker it hits first.
##
## Never instanced; call the static functions directly, e.g.
## `ChannelMasks.mask_for_channel(attack.channel)`.

const LAYER_HURT_LOW := 4
const LAYER_HURT_HIGH := 5
const LAYER_BLOCK_LOW := 6
const LAYER_BLOCK_HIGH := 7

## Godot layer numbers are 1-based; the bitmask bit for layer N is 1 << (N-1).
static func layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)

static func mask_for_channel(channel: AttackDef.Channel) -> int:
	match channel:
		AttackDef.Channel.LOW:
			return layer_bit(LAYER_HURT_LOW) | layer_bit(LAYER_BLOCK_LOW)
		AttackDef.Channel.HIGH:
			return layer_bit(LAYER_HURT_HIGH) | layer_bit(LAYER_BLOCK_HIGH)
		AttackDef.Channel.BOTH:
			return (
				layer_bit(LAYER_HURT_LOW)
				| layer_bit(LAYER_HURT_HIGH)
				| layer_bit(LAYER_BLOCK_LOW)
				| layer_bit(LAYER_BLOCK_HIGH)
			)
		_:
			push_error("ChannelMasks.mask_for_channel: unknown channel %s" % channel)
			return 0

## --- Height → channel (04-COMBAT-MODEL.md §2) -------------------------------
## A projectile carries a `height` scalar (elevation units, 0 = ground). These
## two thresholds slice that continuum into the three channels. Tune by feel:
## widening the HIGH band makes lobs clear walls more easily; a small GROUND
## band means a lob is only "low enough to hit the ground" right at launch/landing.
const HEIGHT_GROUND_MAX := 3.0   ## height < this  → LOW  (at/near the floor)
const HEIGHT_HIGH_MIN := 10.0    ## height >= this → HIGH (up where it clears low walls)
                                 ## in between      → BOTH (transitioning)

static func channel_for_height(height: float) -> AttackDef.Channel:
	if height < HEIGHT_GROUND_MAX:
		return AttackDef.Channel.LOW
	elif height < HEIGHT_HIGH_MIN:
		return AttackDef.Channel.BOTH
	return AttackDef.Channel.HIGH

## Cosmetic only — matches the F5 channel-overlay colors from 03-GYM-SPEC.md
## §5 (LOW = orange, HIGH = blue, BOTH = purple) so projectiles read the same
## way the overlay will. Used by Projectile's debug draw.
static func debug_color(channel: AttackDef.Channel) -> Color:
	match channel:
		AttackDef.Channel.LOW:
			return Color.ORANGE
		AttackDef.Channel.HIGH:
			return Color.DODGER_BLUE
		AttackDef.Channel.BOTH:
			return Color.PURPLE
		_:
			return Color.WHITE
