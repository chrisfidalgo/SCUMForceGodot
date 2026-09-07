# On-hit effects and the slow field

**Scripts:** `scenes/combat/slow_field.gd`, plus `on_hit_effect` /
`effect_trigger` on `resources/attack_def.gd` and the impact handling in
`scenes/combat/projectile.gd`.
**Scenes:** `slow_field_small.tscn`, `slow_field_spill.tscn`,
`cheese_projectile.tscn`.

## The idea

An attack can leave something behind where it ends. `AttackDef.on_hit_effect` is
a `PackedScene` — anything at all — spawned at the impact point. It is empty for
Johnny (his shots are just damage) and set for Curt (his shots leave cheese).

Because it's a scene reference on a resource, **giving an attack a new effect is
an Inspector drag, not a code change.** That is the hook items will eventually
use: a relic that adds a slow field to a character's primary is a data edit.

## Where the effect fires: `effect_trigger`

The two Curt attacks differ mainly in this one field, and the difference is the
whole design.

**`ENEMY_ONLY`** — the effect appears only where the shot actually damaged
something. Miss, and you get nothing. This is Curt's **primary** (Bleu Cheese
Packet): a precise tool that rewards connecting.

**`ANY_IMPACT`** — the effect appears wherever the shot ends: an enemy, a wall,
or simply the ground at the end of its arc. This is Curt's **secondary** (Bleu
Cheese Container Lob), and it's what makes it *area denial* rather than just a
heavier shot. **You can throw it at an empty doorway** and the puddle is still
there when something walks through.

Getting the "lands on bare floor" case right needed a real change: a projectile
that reaches the end of its range used to just delete itself silently. For an
`ANY_IMPACT` attack, running out of arc *is* the impact — the container landed —
so it now goes through the same impact path.

## The slow field

`SlowField` is an `Area2D` that slows enemies standing in it. Two scenes, same
script, different exported numbers:

| | `slow_field_small` (packet) | `slow_field_spill` (container) |
|---|---|---|
| radius | 14 px | 30 px |
| duration | 0.8 s | 2.4 s |
| slow to | 55% speed | 40% speed |
| grow-in | instant | 0.25 s (splashes outward) |

All placeholders, all `@export`s — open either scene and drag.

**Slowing is a set, not a timer.** While an enemy overlaps a field, that field
registers itself on the enemy as one slow source; stepping out releases it
immediately, and two overlapping puddles resolve to the strongest rather than
fighting over a single countdown. An enemy's `speed_multiplier` is just the
minimum of its active sources.

Overlaps are **polled each physics frame** rather than driven by `body_entered`,
because the spill variant grows — bodies already standing where it expands into
would otherwise be missed as the shape resizes.

Slowed enemies are tinted pale blue. That tint is applied to the node's
`modulate`, deliberately *not* to `Visual.color`, because the hit flash already
owns that property and the two would overwrite each other.

**Only enemies are affected.** The field applies to anything implementing
`add_slow()`, which today is `Enemy` alone — Curt is not slowed by his own
cheese. If an enemy ever needs a slowing attack, give `Player` the same two
methods and the field works unchanged. Note the player's own `speed_multiplier`
is owned by the escort loop, so that wiring needs a moment's thought rather than
a copy-paste.

## Placeholder art

`bleu-cheese.png` and the 9-frame `bleu-cheese-explosion.png` from the art
direction **do not exist yet**. Curt fires `cheese_projectile.tscn` — a cream
polygon with darker veins — purely so his shots don't *read as toilet paper*
during the feel playtest. The spill is drawn as a squashed cream oval, matching
how the projectile ground-shadow is drawn, so it reads as lying on the floor.

Swap in the real art by pointing `AttackDef.projectile_scene` at a new scene and
replacing the field's `_draw` with a sprite. Nothing else changes.

## Testing it by hand

Open the gym, **F6**, **F5** to swap to Curt, then:

1. **F1** to spawn a Wanderer. Hit it with **J** (packet). It takes 2 half-hearts,
   turns pale blue, and visibly crawls inside a small cream puddle.
2. Fire **J** into the tall wall. No puddle — `ENEMY_ONLY` means a miss leaves
   nothing.
3. Fire **K** (container lob) at **empty floor**. It still spills, and the puddle
   scales up over a quarter-second. Now walk an enemy through it.
4. Lob **K** over the low wall from the right distance — it clears the wall *and*
   spills on the far side. That combination is Curt's whole answer to a defended
   position.
5. Press **`` ` ``** and drag the packet's and lob's numbers while fighting.

## What to judge

Curt is meant to be the answer to fast enemies. The question for the playtest is
whether slowing something actually *feels* like an answer — whether a Seeker
crawling through cheese reads as a problem you solved, or just as a delay. If it
reads as a delay, the dial to try first is `slow_multiplier` (stronger slow), not
more damage.
