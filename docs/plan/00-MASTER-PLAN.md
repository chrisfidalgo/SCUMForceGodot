# 00 — Master Plan: SCUM Force: American Mayhem (Godot)

Orchestration plan for building the vertical slice in phases, sized for delegation to multiple implementing agents working in parallel. Reading order for any agent picking up a packet: `01-AGENT-BRIEFING.md` → `02-ARCHITECTURE.md` → `04-COMBAT-MODEL.md` → the spec for their packet. Note `04` supersedes the combat sections of `02`/`03`.

Design canon lives in `PROJECT_CONTEXT.md` at the root of this repo. This plan implements its build sequence (`NEXT_STEPS.md`, also at the root): setup → gym → fixed harness → procedural maps → tooling check → vertical-slice content.

Packet sizes: **S** ≈ one focused session, **M** ≈ a substantial session or two, **L** ≈ multi-session. Parallel-safety comes from file ownership: no two concurrent packets touch the same scene or script.

---

## Phase 0 — Foundation (ONE agent, serial — everything else depends on this)

**Packet P0 (M):** the entire contents of `02-ARCHITECTURE.md`:

1. Version control is already set up: local repo on `main`, remote `origin` → `https://github.com/chrisfidalgo/SCUMForceGodot.git`. P0 works on a branch off `main` and pushes.
2. `project.godot`: display/stretch/pixel-art settings, the 8 named physics layers, the full Input Map. **These are frozen after this packet.**
3. Folder structure; `main.tscn` with ScreenRoot / ModalLayer / TooltipLayer skeleton; the four autoload stubs (`GameFlow` with working screen/modal swapping, `RunState`/`SaveManager`/`EventBus` as documented stubs).
4. `CharacterDef` / `AttackDef` resource class scripts, plus the four attack `.tres` and two character `.tres` files with the placeholder values from `03-GYM-SPEC.md`.
5. An empty `gym.tscn` that opens and runs.
6. `docs/systems/00-godot-primer.md`: a one-page designer intro to nodes, scenes, signals, autoloads, resources, and where to find the Inspector knobs — written for the project owner.

**Exit criteria:** project runs; autoload skeleton routes to a placeholder screen; resources visible/editable in Inspector; committed.

---

## Phase 1 — The Gym (specs: `03-GYM-SPEC.md`, `04-COMBAT-MODEL.md`, `05-ENEMY-MODEL.md`)

Two waves of parallel packets, one integration pass.

### Wave 1 (up to 3 agents in parallel)

| Packet | Size | Scope (owns these files only) | Depends on |
|---|---|---|---|
| **P1a — Player controller & aiming** | M | `scenes/characters/player.tscn/.gd`: WASD movement, mouse facing, reads `CharacterDef`, the three aim-type resolvers (FIXED / FORWARD_VECTOR / FREE_CONE), attack-input → fire signal (projectile itself stubbed). | P0 |
| **P1b — Arena, structures & dummies** | M | `gym.tscn` layout, `scenes/structures/*` (low wall, tall wall, platform, exit zone), `scenes/enemies/target_dummy.tscn` with elevation states, hit flash, damage numbers, hit counters. Pure scene/layer work — testable by hand-placing projectiles before P1c lands. | P0 |
| **P1c — Attack & channel system** | M | Projectile scene(s) + `AttackDef`-driven spawning: channel → collision-mask mapping, lob-over-low behavior for HIGH, range expiry, damage delivery to hurtboxes. The heart of the game's identity — the §7.4/§7.5 matrices in the gym spec are its test. | P0 (integrates with P1a's fire signal + P1b's dummies at wave end) |

**Integration pass 1 (S, one agent):** wire P1a+P1b+P1c together in the gym; verify acceptance criteria 1–5.

### Wave 2 — stand the gym up as a game (spec: `05-ENEMY-MODEL.md`) — **DONE 2026-09-07**

Enemies were pulled forward on 2026-09-07 (owner call). Rationale: the gym exists
to answer "does character choice matter?", and that question is unanswerable
against stationary dummies — it only has meaning when something shoots back,
takes cover, or closes distance. Dummies prove the rules; enemies prove the game.
Health lands first because everything else depends on it; the escort loop, which
was previously bundled ahead of enemies, now follows them.

| Packet | Size | Scope (owns these files only) | Depends on |
|---|---|---|---|
| **P1d — Health & damage** | S/M | Shared half-heart health component, player damage intake with i-frames, death → removal. No enemies, no minis — just the damage substrate everything else calls. | Wave 1 |
| **P1e — Enemy archetypes** | M/L | The three behaviours in `05-ENEMY-MODEL.md` (Wanderer / Turret / Seeker), each firing through the existing `AttackSpawner`, each with an `elevation` export, each joining the `tunable` group so its speed/cooldown/range are live-tunable. **Owns the projectile faction fix** (§4 of that doc) — it must land in this packet, not after. | P1d |
| **P1f — Downed state, rescue & exit loop** | M | Downed → mini transformation, pickup/follow-chain, 2+ escort speed penalty, drop-on-death, re-rescue, exit-zone banking, character swap flow. | P1d (parallel with P1e) |
| **P1g — Debug tray & combat HUD** | S/M | `scenes/ui/debug_tray.tscn` (F1–F6 incl. channel-viz overlay and per-archetype spawn), minimal HUD (hearts, cooldowns, mini count). **Complements the `` ` `` tuning panel — does not replace or absorb it.** The tray spawns and inspects; the panel tunes. | Wave 1 (spawn hooks land as P1e/P1f merge) |

**Integration pass 2 — done.** Verified in-engine: all three archetypes spawn
with correct hurt layers, the Seeker closes to its preferred range, an enemy shot
passes through another enemy but damages the player, contact damage lands, going
down leaves a rescuable mini, the escort chain applies its penalty only at 2+,
the chain drops (never vanishes) when the escort falls, the exit banks it, reset
clears the field, and the overlay finds every channel-bearing area. The §6
criterion-3 matrix passes in all four cases: a LOW shot is stopped by the low
wall, a lob clears it and lands, the same lob at the wrong spacing sails
overhead, and with no wall between, the LOW shot connects. **Then the owner playtests the core question: does
Johnny vs. Curt feel meaningfully different, and do the channel rules read
clearly?** Tuning happens here via the Inspector and the in-play `` ` `` panel
before Phase 2 starts.

---

## Phase 2 — Fixed harness + view shell (detailed spec written AFTER gym validates)

Proves the structural plumbing with a hand-built, non-random chain — deliberately before any procedural generation — and builds the screen flow from the owner's view map. Provisional packets:

| Packet | Size | Scope |
|---|---|---|
| P2a — Splash & CharacterSelect | S/M | New Game / Continue / Settings; pick 1–3 roster members to start a run. |
| P2b — Fixed EraMap screen | M | Hand-authored 4-node one-way map collapsing to a boss node; node states (locked/available/cleared); node → screen routing via `GameFlow`. |
| P2c — Real encounter flow in combat | M/L | Shared encounter timer; win by full clear OR all characters exited; per-encounter character selection; survived-character removal from the pool; roster-wipe = run loss; boss variant (no exit, clear only). |
| P2d — Shop & Event modals (stubs) | S/M | Shop modal over EraMap (placeholder cash, buy-heal); Event modal (text + choice → placeholder buff). |
| P2e — Save/Continue | M | `SaveManager` v1 blob per `02-ARCHITECTURE.md` §6, save after every resolved node, Continue restores to EraMap. |
| P2f — RunSummary + Inventory modal + Tooltips | M | Full-screen win/loss summary looping back to Splash; roster/items inventory modal; singleton tooltip layer. |

## Phase 3 — Procedural era maps
Branching node-map generation (arcs drawn from the 5-era pool, node-count ranges, event/merchant placement, all paths collapsing to the boss). Spec written only after Phase 2 proves the plumbing, per `NEXT_STEPS.md`.

## Phase 4 — Tooling check & vertical-slice content
Author a real encounter purely in Godot's scene editor; decide whether any custom tooling is needed. Then swap gym placeholders for real early content (Bag Guys reskinned per era as the placeholder-to-real bridge).

---

## Out of scope until explicitly scheduled
Multiplayer (any form) · real reward/relic balancing · ascension/death-permanence tuning · currency system beyond placeholder cash · event-node content beyond stubs · controller input (post-gym packet, before Phase 2 playtests at earliest) · audio.

## Resolved by the owner (2026-07-07)
- **Boss camera:** larger authored canvas (e.g. 800×450 with camera zoom to match) for the first pass — not zoom-on-640×360 (`02-ARCHITECTURE.md` §2).
- **Inventory modal:** built as a self-contained modal so it *could* be opened from any screen later; MVP wires it to EraMap only.
- **Escort penalty:** flat −25% at 2+ minis stands as the placeholder; tune by feel in the gym.
- **Character select (Phase 2):** full 1–3 roster pick is the target, not a fixed pair.

## Open questions (owner decisions pending — see also PROJECT_CONTEXT.md's list)
1. **Settings screen scope** for the vertical slice — TBD; expect answers to emerge from gym playtesting.
