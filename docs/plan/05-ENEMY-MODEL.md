# 05 — Enemy Model

Spec for the enemy archetypes that stand the gym up as a *game* rather than a
shooting range. Written before implementation so the gym gets built once.

Read `04-COMBAT-MODEL.md` first — enemies are consumers of the channel/height
model defined there, not a parallel system.

---

## 1. Why these three, and why now

The source material (Gain Ground) gets a surprising amount of tactical depth out
of enemies with almost no intelligence. Three behaviours carry the whole game:

1. **Wanderer** — moves, never attacks. A body in the way.
2. **Turret** — never moves, fires on a timer. A zone you cannot stand in.
3. **Seeker** — moves to get into range, then fires. A threat that closes.

That is the whole starting set. Nothing here needs pathfinding, state-machine
frameworks, steering behaviours, or a behaviour tree — and adding those early
would bury the actual design question under architecture.

**Why they move earlier in the plan:** the gym's job is to answer "does
character choice matter?" A player cannot answer that against stationary
dummies. Choosing Johnny over Curt only means something when something is
shooting back, taking cover behind a wall, or closing distance. The dummies
prove the *rules* work; enemies prove the *game* works. See `00-MASTER-PLAN.md`
Phase 1 Wave 2.

---

## 2. The three archetypes

All numbers are **placeholder** and belong in the Inspector (an `@export` or a
`.tres` resource file), never in code. Tune by feel in the gym.

| | **Wanderer** | **Turret** | **Seeker** |
|---|---|---|---|
| Moves | Yes, aimlessly | No | Yes, toward the player |
| Attacks | No | Yes | Yes |
| Threat | Body contact | Projectile | Projectile |
| HP (half-hearts) | 2 | 2 | 3 |
| Move speed (px/s) | 40 | — | 55 |
| Fire cooldown (s) | — | 1.8 | 2.2 |
| Preferred range (px) | — | — | 120 |
| Tests | Contact damage, crowding, positioning | Cover, channel-blocking, zoning | Spacing, kiting, retreat pressure |

**Wanderer.** Picks a random direction, walks a second or two, picks another.
Reverses when it hits a wall. Damages the player on body contact, with a
per-target cooldown so touching it is not instant death. This is the Bag Guy
already specced in `03-GYM-SPEC.md` §3, minus the beeline-at-the-player chase —
wandering reads as *dumb fodder*, which is what a Bag Guy is.

**Turret.** Stands still and fires its `AttackDef` along a fixed facing on a
cooldown. First pass fires along its authored facing (set in the editor by
rotating the node), **not** tracking the player — a turret you can walk around
is a spatial puzzle; a turret that tracks you is just pressure. A tracking
variant is a later dial, not the default.

**Seeker.** If further than `preferred_range` from the player, walk toward them.
If closer than `preferred_range * 0.75`, back away. Otherwise hold and fire on
cooldown. That single rule produces the "closes, then commits" feel without a
state machine. Movement is a direct vector toward or away from the player —
**no pathfinding**; walls are handled by the same collision the player uses.

---

## 3. What they reuse (do not rebuild any of this)

The point of speccing enemies after Wave 1 is that most of the machinery exists.

- **Attacks: `AttackDef` + `AttackSpawner`.** `AttackSpawner.spawn_attack(attack,
  origin, aim_direction, source)` already takes an arbitrary `source` and never
  assumes the player fired. An enemy fires by calling the exact same method.
  This means **enemy attacks are authored as `.tres` resource files and tuned in
  the Inspector**, identically to player attacks — an enemy that lobs over a low
  wall costs a resource file, not code.
- **Channels: `ChannelMasks`.** Enemy projectiles carry a channel like any other,
  so **structures block enemy fire the same way they block yours**. This is what
  turns a low wall into cover and makes positioning matter. It is the single
  most important reason to build enemies on the shared pipeline.
- **Elevation: the hurtbox layer flip.** `TargetDummy` already demonstrates the
  pattern — an `elevation` export moves the hurtbox between the `hurt_low` and
  `hurt_high` physics layers, with no code branch anywhere else. Enemies use the
  same approach, so an enemy on a platform is only reachable by HIGH attacks.
- **Damage in: `receive_hit(damage_half_hearts)`.** The existing hurtbox
  contract. Keep the name and signature exact.

---

## 4. The one real gap: telling friend from foe

**This is the seam that will break if it is not decided up front.**

Today `Projectile` resolves a hit against anything on the `hurt_low`/`hurt_high`
physics layers, excluding only the single node that fired it (`_ignore`). Those
hurt layers are faction-agnostic — they describe *height*, not *side*. The
moment enemies start shooting, an enemy's projectile will happily damage another
enemy standing in the way.

**The fix is a script-level faction check, not new physics layers.** The eight
layer names are frozen after Phase 0 (`01-AGENT-BRIEFING.md`) and there are no
free slots. So:

- Give `Projectile` a faction field, set from the `source` in `setup()`.
- In `_resolve_overlaps()`, skip a hurt target belonging to the same faction, and
  keep flying rather than treating it as a blocker.
- Blockers (`block_low`/`block_high` — walls) stay faction-blind: a wall stops
  everyone.

Whoever builds the first shooting enemy owns this change to `projectile.gd`, and
it must land in the same packet — a half-built faction check is worse than none.

**Design guardrail:** friendly fire between enemies is *off* by default. Enemies
blocking each other's shots sounds tactical but reads as bugs at this scale.

---

## 5. Explicitly not now

No pathfinding or navmesh. No behaviour trees or a state-machine framework. No
flocking, formations, or squad coordination. No enemy melee wind-ups or
telegraphed heavy attacks. No spawn waves or director. No boss behaviour — the
canon's "bosses are not 8-gate-limited" idea (`04-COMBAT-MODEL.md`) is a Phase 3+
concern. No per-era reskins yet.

If an archetype seems to need one of these to be interesting, that is worth
knowing — but flag it rather than building it.

---

## 6. Acceptance

The gym stands up when, with the debug tray, the owner can:

1. Spawn any of the three archetypes on demand, at a chosen elevation.
2. Take damage from a Wanderer's body and from a Turret's projectile, and see
   hearts drop.
3. **Stand behind a low wall and be safe from a LOW enemy shot, then be hit by a
   HIGH one from the same spot.** This is the whole game in one test.
4. Kill each archetype and see it die.
5. Watch a Seeker close from across the arena, stop at range, and fire.
6. Confirm an enemy projectile passes harmlessly through another enemy.

Criterion 3 is the one that matters. If it does not read clearly to a player,
the channel system has a presentation problem, and that is worth finding now
rather than after Phase 2 is built on top of it.
