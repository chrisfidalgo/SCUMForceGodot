# 06 — Enemy Behaviours & Encounters

Spec for Phase 1 Wave 3: composable enemy behaviours, an `Encounter` base that
every level shares, and a short fixed chain of hand-built levels to prove the
structure. Written 2026-11-01 from the owner's brief:

> Enemies who stand in place until the player comes within range, then activate.
> Enemies who wander, who patrol, who seek. Enemies who attack with melee or
> ranged. Basic levels to help validate the structure. Keep the gym for testing.

**Supersedes:** `05-ENEMY-MODEL.md` §2 (the three fixed archetypes become three
presets of the model below) and the "no melee wind-ups" line of its §5. Its §3
(reuse the player's pipeline) and §4 (faction check) stand unchanged.
**Pulls forward:** a lean slice of Phase 2's P2c (real encounter resolution and
per-encounter character choice). P2b's map screen is still Phase 2.

Owner decisions (2026-11-01): melee has a short tunable wind-up; levels are a
chained run, not standalone; behaviours are *building blocks* meant to be
combined into more complex enemies later, so leashing is a per-type option
rather than a global rule. **Time's Out** (timer hits 0) ends the stage and
removes one random character from the run. Every combat stage must have enemies.

---

## 1. The idea in one paragraph

Today an enemy's archetype welds movement to attack: Wanderer = walks + never
fires. Split them. An enemy is **three independent choices** — *when it wakes*,
*how it moves*, *how it attacks* — plus numbers, all saved in an `EnemyDef`
`.tres`. New enemy = new file. The old Wanderer / Turret / Seeker become three
such files and must play identically to today.

## 2. The behaviour model (`resources/enemy_def.gd` — already written, read it)

| Axis | Options | Notes |
|---|---|---|
| **Activation** | ALWAYS · PROXIMITY | PROXIMITY wakes at `activation_range_px`, or when hit if `wake_on_damage`. Optional leash (`leash_enabled`, `leash_range_px`) sends it back to dormant. No line-of-sight check — distance only. |
| **Movement** | STATIONARY · WANDER · PATROL · SEEK | Chosen **twice**: `idle_movement` (while dormant) and `active_movement`. That is what makes "patrols until it spots you, then chases" a data choice. |
| **Attack** | NONE · MELEE · RANGED | Only while active. Fires through `AttackSpawner` like everything else. `windup_sec` > 0 = stop, show a tell, direction locked, then attack. Melee is a short-range `AttackDef`. |

**Per-placement, on the Enemy node (not the def):** `def: EnemyDef`,
`elevation` (unchanged), `facing_degrees` (for FIXED_FACING aim; replaces
`turret_facing_degrees`), `patrol_route: Node2D`.

**Patrol route contract:** any `Node2D`; its `Marker2D` children, in tree order,
are the waypoints, in global coordinates. A PATROL enemy with no route (or no
markers) stands still and `push_warning`s — it must not crash.

**Legibility is required, not polish.** At a glance the player must be able to
tell: dormant vs active (e.g. dimmed + "z" → brief "!" on wake), and a wind-up in
progress (e.g. flash/pulse in the attack's colour). Placeholder art is fine;
invisible state is not. `modulate` is already owned by the slow tint and
`_visual.color` by the hit flash — use something else (a child label/sprite, or
`self_modulate`).

### Presets to ship (`resources/enemies/*.tres`)

| File | Activation | Idle → Active move | Attack | Notes |
|---|---|---|---|---|
| `wanderer.tres` | ALWAYS | — → WANDER | NONE | 2 HP, 40 px/s. **= today's Wanderer.** |
| `turret.tres` | ALWAYS | — → STATIONARY | RANGED, FIXED_FACING, `bag_lob` | 2 HP, 1.8 s. **= today's Turret.** |
| `seeker.tres` | ALWAYS | — → SEEK | RANGED, AT_PLAYER, `bag_shot` | 3 HP, 55 px/s, 2.2 s, 120 px, ratio 0.75. **= today's Seeker.** |
| `sentry.tres` | PROXIMITY | STATIONARY → STATIONARY | RANGED, AT_PLAYER | Sleeps until you're close, then shoots. |
| `patroller.tres` | PROXIMITY | PATROL → SEEK | RANGED | Walks a beat; chases when it spots you. Leash on. |
| `brawler.tres` | ALWAYS | — → SEEK | MELEE, wind-up ~0.3 s | `retreat_ratio` 0, preferred range ≈ reach. |
| `lurker.tres` | PROXIMITY | STATIONARY → SEEK | MELEE, wind-up | Ambusher behind cover. |
| `bag_boss.tres` | ALWAYS | — → SEEK | RANGED, AT_PLAYER | Beefy placeholder boss (~10 HP). Not a boss *design* — a stand-in for a clear-only room. |

Plus one new attack, `resources/attacks/enemy_swipe.tres`: LOW, GROUND, short
range (~24 px), fast, 1 half-heart. All numbers placeholder; tune in play.

---

## 3. The encounter model (`scenes/combat/encounter.gd`, `class_name Encounter`)

Everything `gym.gd` does today that is not debug — firing, enemy registration,
going down, the escort chain, exit banking — moves into `Encounter`. The gym
becomes `extends Encounter` plus its `debug_*` methods. Every level is an
`Encounter` scene built in the editor.

### Canon it implements (`PROJECT_CONTEXT.md` combat encounter, steps 1–6)

- Pick **one** character from this encounter's pool; they spawn at `PlayerSpawn`.
  The tree is **paused while choosing** — choosing is never under fire.
- Reaching the exit = **survived**: banks escorted minis, removes that character
  from this encounter's pool, then prompts the next pick.
- Going down = a mini on the field (unchanged), then prompts the next pick.
- **Resolution:**
  - all enemies dead → `CLEARED`
  - pool empty and ≥1 survived → `ESCAPED`
  - pool empty and none survived → `LOST` (the run is over)
  - timer reaches 0 → `TIMED_OUT` (see Timer below)
- **Boss** (`is_boss = true`): exit disabled/hidden; only `CLEARED` or `LOST`.
- **Sandbox** (`sandbox = true`, the gym): never resolves, pool never shrinks,
  first character auto-deploys, F5 swap keeps working. The gym must play
  exactly as it does today.
- **Timer** (`time_limit_sec`, 0 = none): counts down, shown on the HUD. At 0 it
  emits `timer_expired` and resolves `TIMED_OUT` ("TIME'S OUT" on screen).
  Characters who already exited count as survived; the active character and the
  undeployed are neither survived nor downed. The **random removal is the run
  harness's job** (§4), not the encounter's — the encounter only reports.
  Sandbox ignores the timer.
- **Every combat stage must have enemies.** A non-sandbox encounter with none
  at `_ready` calls `push_error` naming the scene.

### Pinned contract — both Wave-1 packets code against exactly this

```gdscript
class_name Encounter extends Node2D

enum Outcome { CLEARED, ESCAPED, LOST, TIMED_OUT }

@export var display_name: String = ""
@export var is_boss: bool = false
@export var sandbox: bool = false
@export var time_limit_sec: float = 0.0
@export var escort_penalty_multiplier: float = 0.75   # moved from gym.gd
## Used when RunState.roster is empty (running a level alone with F6).
@export var default_roster: Array[CharacterDef] = []

signal escort_changed(count: int)                          # unchanged from gym.gd
signal character_banked(name: String, minis_banked: int)   # unchanged from gym.gd
signal deploy_requested(choices: Array[CharacterDef])
signal timer_changed(seconds_left: float)
signal timer_expired
signal resolved(outcome: Outcome, report: Dictionary)

func spawn_enemy(def: EnemyDef, elevation: Enemy.Elevation = Enemy.Elevation.GROUND,
        at: Vector2 = Vector2.INF, patrol_route: Node2D = null) -> Enemy
func register_enemy(enemy: Enemy) -> void      # was _register_enemy; now public
func deploy(def: CharacterDef) -> void         # the picker calls this
func deployable() -> Array[CharacterDef]
func active_player() -> Player                 # unchanged
func escort_count() -> int                     # unchanged
func is_invincible() -> bool                   # unchanged
```

**Report dictionary** (keys are `CharacterDef.resource_path` — that is the
roster id; `CharacterDef` has no id field and must not gain one in this wave):

```gdscript
{
    "survived": { "<path>": half_hearts_left, ... },  # exited, or alive at CLEARED
    "banked":   [ "<path>", ... ],                     # minis carried out the exit
    "downed":   [ "<path>", ... ],                     # went down and were not banked
}
```

**Roster in:** if `RunState.roster` is non-empty, the pool is its members with
`status == "active"`, each starting at their stored `half_hearts`. Otherwise the
pool is `default_roster` at full health. `Encounter` reads RunState; it never
writes it — the run harness owns that (§4).

**Required child nodes** (by name): `Player`, `AttackSpawner`, `PlayerSpawn`,
`Camera2D`, `CombatHUD`, `DeployPicker`, and `ExitZone` unless `is_boss`.
P1i ships `scenes/combat/encounter_base.tscn` containing all of them plus arena
bounds; **levels are inherited scenes of it** (editor: Scene → New Inherited
Scene), so a level is just layout.

**Enemies placed in the editor** are registered on `_ready` from the `enemies`
group, as today. The clear check must ignore enemies already dying (they
`queue_free` on death) — check deferred, or count on the `died` signal.

---

## 4. The fixed run (`scenes/run/fixed_run.tscn/.gd`)

A deliberately dumb harness: an ordered list of level scenes, played in order.

- Exports: `levels: Array[PackedScene]`, `starting_roster: Array[CharacterDef]`,
  `banked_return_half_hearts: int` (a mini carried out comes back with this),
  `downed_return_half_hearts: int` (an unrescued character returns next level
  with this — the easiest death-permanence tier from canon),
  `time_out_removals: int = 1` (how many random roster members a Time's Out
  costs). Removed members get `status = "lost"`; announce who on the card. If
  that leaves no active members, the run is lost.
- On start: `RunState.reset()`, fill `RunState.roster` from `starting_roster` at
  full health (`id` = resource path).
- Instance level *n* as a child; on `resolved`, write the report back into
  `RunState.roster`, emit `EventBus.encounter_resolved`, free the level, show a
  between-levels card ("CLEARED — next: Turret Gauntlet · Enter"), load *n+1*.
- `LOST`, or resolving the last level: a run-end card (won/lost, who survived),
  Enter restarts. No save, no map screen, no shop — those are Phase 2.
- Runs with **F6 on `fixed_run.tscn`**. `main.tscn` / F5 stay untouched until P2a.

### The levels (`scenes/levels/`)

Each answers one question. Placeholder layouts; the owner reworks them.

| Scene | Question it asks | Contents |
|---|---|---|
| `level_01_patrol.tscn` | Do dormant/patrol/wake read clearly? | 2 patrollers on routes, 2 sentries behind low walls, an exit. |
| `level_02_gauntlet.tscn` | Is cover real against both channels? | Turrets on FIXED_FACING lanes, some lobbing (HIGH), low walls, exit at the far end. |
| `level_03_open_field.tscn` | Does Johnny vs Curt matter under pressure? | Seekers + brawlers + a lurker, sparse cover, `time_limit_sec` set. |
| `level_04_boss_room.tscn` | Does a clear-only room resolve right? | `is_boss`, `bag_boss` on a platform-adjacent spot plus 2 wanderers. |

Boss canvas stays 640×360 for now (the 800×450 boss canvas from the master plan
is a later pass).

---

## 5. Packets

File ownership is what keeps parallel packets off each other. **Do not edit a
file another packet owns** — if you need a change there, note it in your
handoff instead.

### Wave 1 — two agents in parallel, off the same base commit

**P1h — Enemy behaviours (M/L).** Owns: `scenes/enemies/enemy.gd/.tscn`,
`scenes/enemies/patrol_route.gd` (optional `@tool` that draws the route in the
editor), `resources/enemies/*`, `resources/attacks/enemy_swipe.tres`,
`scenes/ui/debug_tray.gd`, `scenes/ui/tuning_panel.gd` (**one change only**:
`node.get/set(prop)` → `node.get_indexed/set_indexed(prop)` in `_spec_slider`
and the log, so specs can say `"def:move_speed"`), `scenes/enemies/enemy_sandbox.tscn/.gd`
(its own test scene), `docs/systems/enemy-behaviours.md`, and adding fields to
`resources/enemy_def.gd` (never renaming/removing).
- Remove `Enemy.Archetype`; behaviour comes from `def`. Keep `Enemy.Elevation`,
  `receive_hit`, `add_slow`/`remove_slow`, `attack_fired`, `died`, `faction`,
  the `enemies`/`tunable` groups exactly as they are.
- Tuning spec exposes the def's numbers that matter for the enemy's choices
  (speed, cooldown, wind-up, ranges) via `"def:<field>"`, and the label is
  `"<display_name> (<ELEVATION>)"`.
- Debug tray: F1 spawns the selected type, F2/F3 cycle the type (list built from
  `resources/enemies/` at runtime), F4–F6 unchanged. Spawns call
  `_gym.spawn_enemy(def, Enemy.Elevation.GROUND, Vector2.INF, _gym.get_node_or_null("PatrolRoute"))`.
  The input map is frozen — reuse `debug_1`…`debug_6`.
- **Will not compile against the old gym until merged with P1i** — that is
  expected. Test in `enemy_sandbox.tscn` (player + spawner + walls + a route,
  minimal wiring copied, not shared).

**P1i — Encounter core (M/L).** Owns: `scenes/combat/encounter.gd`,
`scenes/combat/encounter_base.tscn`, `scenes/combat/gym.gd` (+`gym.tscn`: set
`sandbox = true`, add a `PatrolRoute` Node2D with 3–4 `Marker2D` children),
`scenes/combat/health.gd` (add `set_current(half_hearts)`), `scenes/ui/combat_hud.gd/.tscn`
(timer + level name), `scenes/ui/deploy_picker.gd/.tscn`, `docs/systems/encounters.md`.
- Implement §3 to the letter, signatures included. `spawn_enemy` instances
  `enemy.tscn`, sets `def`, `elevation`, `patrol_route` **before** `add_child`,
  then positions and registers it. It references `EnemyDef` (already on disk)
  and `Enemy.Elevation` — nothing from `Enemy.Archetype`.
- The picker: number keys + clickable buttons, `process_mode = ALWAYS`, unpauses
  on pick. Show HP per character.
- Verify the gym still plays as before (spawn/down/swap/reset/escort/exit) —
  with P1h absent, use `push_warning` stubs only if unavoidable.

### Wave 2 — one agent, after both merge

**P1j — Levels, fixed run & integration (M).** Owns: `scenes/run/*`,
`scenes/levels/*`, `docs/systems/fixed-run.md`; may make **integration-only**
fixes anywhere, each called out in its handoff. Merges P1h + P1i, fixes the
seams, builds §4, runs §6.

---

## 6. Acceptance (P1j verifies, in-engine)

1. The gym plays exactly as before; F1–F3 spawn any preset including a
   patroller on the gym's route.
2. Wanderer / Turret / Seeker presets behave as the old archetypes did.
3. A sentry ignores you until you're in range, wakes visibly, then shoots; hitting
   it from outside its range also wakes it.
4. A patroller walks its route, chases on sight, and (leash on) returns to the
   route when you get away.
5. A brawler's wind-up is visible and side-steppable; a low wall stops its swipe.
6. Retuning `def:move_speed` in the `` ` `` panel changes every enemy of that type.
7. `fixed_run.tscn` with F6: pick a character, exit with one and get prompted for
   the next; resolve a level each of the three ways (CLEARED, ESCAPED, LOST);
   HP carries into the next level; an unrescued character comes back at
   `downed_return_half_hearts`; the boss room has no exit and resolves only by
   clear or wipe; letting the timer run out on level 3 shows TIME'S OUT and
   removes exactly one random roster member for the rest of the run.
   An encounter scene with no enemies logs an error.
8. Each level also runs standalone with F6 using its `default_roster`.
9. Headless boot is clean.

---

## 7. Open owner questions

1. ~~Timer expiry~~ — answered 2026-11-01: Time's Out, one random character
   removed from the run (§3, §4).
2. **Clearing a room with a mini still lying on the field** — recovered
   automatically, or counted as downed? Placeholder: downed (it still returns
   next level under the easiest tier, so the difference is only HP).

## 8. Owner direction for later (recorded, not built this wave)

From the owner, 2026-11-01. Gain Ground is inspiration, not the target — keep
its deliberate, slower pace with tight timings moment to moment, but be less
punishing overall (its Time's Out reset everyone to the base three; ours costs
one character).

- **Health persists between levels** (already the model). Most characters take
  2–4 hits; a few are built for survivability.
- **Rescuing a character you already have improves them** rather than acting as
  a spare life — more hearts, a changed or improved attack pattern, better
  attributes. This is a future packet; nothing in this wave should block it
  (keep roster ids as resource paths and per-character state in `RunState`).

## 9. Still not now

Line-of-sight, pathfinding, alert-your-neighbours, formations, spawn waves,
real boss behaviour, map screen, shop/events, saving, character select screen.
Each is a natural next building block; flag any level that seems to need one.
