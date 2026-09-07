# Enemies, the debug tray, and the HUD

**Scripts:** `scenes/enemies/enemy.gd` (+ `enemy.tscn`),
`scenes/ui/debug_tray.gd`, `scenes/ui/combat_hud.gd`,
`scenes/combat/channel_overlay.gd`. Spec: `docs/plan/05-ENEMY-MODEL.md`.

## One scene, three behaviours

`enemy.tscn` is a single scene with an `archetype` dropdown in the Inspector, the
same way `TargetDummy` has an `elevation` dropdown. A Wanderer and a Seeker are
the same scene with a different value — not two scripts.

| | **Wanderer** | **Turret** | **Seeker** |
|---|---|---|---|
| Moves | random walk, reverses off walls | no | toward/away from you |
| Attacks | no | yes, on a timer | yes, when in range |
| Threat | body contact | lobbed shot (clears low walls) | flat shot (walls stop it) |
| HP / speed | 2 / 40 | 2 / — | 3 / 55 |

All numbers are placeholders and all are `@export`s.

**The Turret does not track you.** It fires along `turret_facing_degrees`,
authored in the Inspector. A turret you can walk around is a spatial puzzle; one
that follows you is just pressure. Tracking is a dial we can add later, not the
default.

**The Seeker has no state machine.** One rule: further than `preferred_range_px`
→ close; nearer than 75% of it → back off; in between → stand and fire. That
alone produces "closes, then commits".

There is deliberately **no pathfinding, no navmesh, and no behaviour tree.**
Gain Ground's depth comes from placement and channels, not clever AI. If an
archetype seems to need more, that is a finding worth reporting, not something to
quietly build.

## Enemies use the player's pipeline

An enemy does not have bespoke attack code. It emits `attack_fired` — the exact
same signal the player emits — and the gym's `AttackSpawner` builds the
projectile. Three consequences worth knowing:

1. **Enemy attacks are `.tres` files** (`bag_shot.tres`, `bag_lob.tres`), tuned
   in the Inspector like the player's.
2. **Enemy shots obey the channel rules**, so structures block enemy fire exactly
   as they block yours. That is what makes a low wall into *cover* rather than
   decoration — the single most important reason to build it this way.
3. A projectile passes through same-side hurtboxes, so enemies never shoot each
   other. See `health-and-rescue.md` for how sides are resolved.

### Elevation

`elevation` flips which hurt layer the enemy sits on: GROUND is reachable only by
LOW attacks, ELEVATED only by HIGH, TALL by both. Purely a layer change — no
behaviour differs. Put a Seeker on ELEVATED and Johnny's TP Roll simply cannot
touch it; he has to lob.

### Live tuning

Every enemy joins the `tunable` group, so its speed, cooldown, contact damage,
preferred range and its whole attack show up in the **`` ` `` panel** while the
game runs. Retune a fight without leaving play mode — see
`docs/systems/tuning-panel.md`.

## The debug tray

Bottom-left panel, in the gym. Every action is both a hotkey and a button.

| Key | Action |
|---|---|
| F1 | Spawn a Wanderer at a random edge |
| F2 | Spawn a Turret |
| F3 | Spawn a Seeker |
| F4 | Force the active character down |
| F5 | Swap to the next roster character |
| F6 | Reset: clear enemies, minis and projectiles, reset dummy counters, restore health |

**Button-only:** *Channel overlay* and *Invincibility*.

> **Why those two have no hotkey:** the input map is frozen after Phase 0, so
> exactly six debug actions exist (`debug_1`..`debug_6`). Three spawns plus
> down/swap/reset uses all six. If either earns a key during playtesting, that's
> a request to unfreeze one input — not something to patch in locally.

The tray never implements a behaviour. It calls a `debug_*` method on the gym, so
the rules stay in one place and the tray can drop into a future encounter scene
unchanged.

## The channel overlay

The most useful debug tool here. It outlines every hurtbox and blocker in the
arena, tinted by channel:

- **orange = LOW** — only a low attack reaches or is stopped here
- **blue = HIGH** — only a high attack
- **purple = BOTH**

Blockers are drawn thinner than things you can damage.

The channel system is the game's identity and is otherwise completely invisible;
a player whose shot sails over an enemy learns nothing from it. Turn this on and
the whole matrix is legible at a glance, which is also the fastest way to spot a
mis-set layer. Treat it as a prototype of possible player-facing readability UI —
judge how it *looks*, not just whether it's correct.

## The HUD

Top-left: half-heart pips, the active character's name, two cooldown bars
(J primary, K secondary), and the escort count. Placeholder art throughout — the
point is judging feel without pausing.

Hearts are drawn at half-heart granularity because that is the damage unit; a HUD
showing only whole hearts would make half of all damage invisible. A cooldown bar
reads full when the attack is on cooldown and empties as it becomes ready, so
"empty means go".

## The test that matters

With an enemy spawned, stand behind the low wall on the left:

- A **Seeker's** flat shot is stopped by the wall. You are safe.
- A **Turret's** lobbed shot arcs over it and lands on you. You are not.
- Stand too close to that turret and the same lob sails **over** you — it is
  still climbing. Height is driven by distance travelled, so clearing a wall is a
  spacing skill and both too-close and too-far fail.

If that reads clearly to a player without the overlay on, the channel system
works. If it doesn't, that is a presentation problem worth finding now rather
than after Phase 2 is built on top of it.
