# Enemies, the debug tray, and the HUD

**Scripts:** `scenes/enemies/enemy.gd` (+ `enemy.tscn`), `resources/enemy_def.gd`,
`scenes/ui/debug_tray.gd`, `scenes/ui/combat_hud.gd`,
`scenes/combat/channel_overlay.gd`. Specs: `docs/plan/05-ENEMY-MODEL.md` and
`docs/plan/06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md`.

## One scene, any behaviour

`enemy.tscn` is a single scene; what an enemy *does* comes from an `EnemyDef`
`.tres` file in `resources/enemies/` (when it wakes, how it moves, how it
attacks, plus the numbers). Wanderer, Turret, Seeker, Sentry, Patroller,
Brawler, Lurker and Bag Boss are all just different files. The full model, the
preset table and how to make a new type are in **`enemy-behaviours.md`** - read
that first; this page only covers the tools around enemies.

There is deliberately **no pathfinding, no navmesh, and no behaviour tree.**
Gain Ground's depth comes from placement and channels, not clever AI. If a
behaviour seems to need more, that is a finding worth reporting, not something
to quietly build.

## Enemies use the player's pipeline

An enemy does not have bespoke attack code. It emits `attack_fired` — the exact
same signal the player emits — and the gym's `AttackSpawner` builds the
projectile. Three consequences worth knowing:

1. **Enemy attacks are `.tres` files** (`bag_shot.tres`, `bag_lob.tres`, `enemy_swipe.tres`), tuned
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

Every enemy joins the `tunable` group, so the numbers that matter for its
behaviour (speed, cooldown, wind-up, ranges) and its whole attack show up in the **`` ` `` panel** while the
game runs. Retune a fight without leaving play mode — see
`docs/systems/tuning-panel.md`.

## The debug tray

Bottom-left panel, in the gym. Every action is both a hotkey and a button.

| Key | Action |
|---|---|
| F1 | Spawn the **selected** enemy type at a random edge (a patroller goes on the gym's `PatrolRoute`) |
| F2 | Select the next enemy type |
| F3 | Select the previous enemy type |
| F4 | Force the active character down |
| F5 | Swap to the next roster character |
| F6 | Reset: clear enemies, minis and projectiles, reset dummy counters, restore health |

The type list is built at runtime from every `.tres` in `resources/enemies/`,
so a new enemy file appears in the F2/F3 cycle with no code change.

**Button-only:** *Channel overlay* and *Invincibility*.

> **Why those two have no hotkey:** the input map is frozen after Phase 0, so
> exactly six debug actions exist (`debug_1`..`debug_6`). Spawn, two cycle keys
> and down/swap/reset use all six. If either earns a key during playtesting,
> that's a request to unfreeze one input - not something to patch in locally.

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

With enemies spawned (F2 to pick a type, F1 to spawn), stand behind the low
wall on the left:

- A **Seeker's** flat shot is stopped by the wall. You are safe.
- A **Turret's** lobbed shot arcs over it and lands on you. You are not.
- Stand too close to that turret and the same lob sails **over** you — it is
  still climbing. Height is driven by distance travelled, so clearing a wall is a
  spacing skill and both too-close and too-far fail.

If that reads clearly to a player without the overlay on, the channel system
works. If it doesn't, that is a presentation problem worth finding now rather
than after Phase 2 is built on top of it.
