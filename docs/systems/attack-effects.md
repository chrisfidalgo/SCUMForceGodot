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
| radius | 9 px | 24 px |
| duration | 0.5 s | 1.5 s |
| slow to | 60% speed | 40% speed |
| grow-in | instant | 0.15 s |
| burst | none | 9-frame explosion first |

The two are deliberately different *kinds* of thing, not big and small versions
of one thing. The packet's pool is close to negligible — a nudge that makes a hit
feel like it stuck. The container's pool is the one that controls space: 24px is
wide enough to hold **one or two enemies at once** (verified with two enemies
28px apart, both slowed).

All `@export`s — open either scene and drag.

### The burst comes first

The container plays the 9-frame explosion sheet **before** any cheese is on the
ground. During the burst nothing is slowed and the pool has zero radius; when the
last frame finishes the sprite hides and the pool grows in. Measured: 9 frames
over 22 physics frames at 24 fps, then handover.

Give any field a burst by adding a `Burst` `Sprite2D` child with a sheet and its
`hframes` set; a field without one skips straight to the pool.

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

## Art

- **Projectile:** `Proj-BlueCheese.png` (10×14), wired into
  `cheese_projectile.tscn`. It has **no Tail node** — the cheese is a simple
  projectile, unlike the unrolling toilet paper. `projectile.gd` looks the tail
  up with `get_node_or_null`, so its absence is expected and handled.
- **Burst:** `Proj_Bleu_Cheese_Explosion-Sheet.png` (360×40 = 9 horizontal frames
  of 40×40), on the spill field's `Burst` sprite with `hframes = 9`.
- **Pool:** drawn, not a sprite — a near-white oval with a cold blue cast,
  squashed the same way the projectile's ground shadow is so it reads as lying on
  the floor. It holds full opacity for two-thirds of its life then fades, so it
  looks solid rather than continuously dying.

### Where the splat lands, and why it matters

An impact effect spawns at the **projectile's contact point**, not at the centre
of whatever it hit. Those are different places, and the difference is the
difference between seeing the pool and not.

A ground decal correctly renders *underneath* the things standing on it. So a
pool spawned at a target's centre sits under that target's sprite and is hidden
by it — completely, if the sprite is bigger than the pool. The gym's target
dummies are 20×28, larger than the primary's 9px pool, so a centre-spawned pool
was 100% invisible against them. Spawned at the contact point it now clears the
body by ~10px and reads immediately.

### Target dummies cannot be slowed

Worth knowing when QA-ing: the gym's stationary dummies are `Node2D` hit-test
targets, not combatants. They are not physics bodies on `enemy_body`, and they do
not implement `add_slow`. Pools **do** spawn on them (that path works), but
nothing is slowed and nothing is tinted, because there is nothing there to slow.

**Use real enemies — F1/F2/F3 — to QA the slow itself.** The dummies are for the
channel/elevation matrix; the enemies are for everything about damage and
control.

### Draw order — the thing that makes a ground effect invisible

The gym floor is an **opaque `ColorRect`**. A ground effect below it in draw
order simply cannot be seen, and nothing warns you. The floor now sits at
`z_index = -10` and the fields at `-1`, giving: floor → pools → everything
standing on them. If you add another ground effect, put it between those two.

## Testing it by hand

Open the gym, **F6**, **F5** to swap to Curt, then:

1. **F1** to spawn a Wanderer. Hit it with **J** (packet). It takes 2 half-hearts,
   turns pale blue, and briefly crawls inside a small near-white puddle. It is
   meant to be nearly negligible — the lob is what controls space.
2. Fire **J** into the tall wall. No puddle — `ENEMY_ONLY` means a miss leaves
   nothing.
3. Fire **K** (container lob) at **empty floor**. The explosion plays first,
   then the pool grows in and stands for 1.5s. Now walk an enemy through it.
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
