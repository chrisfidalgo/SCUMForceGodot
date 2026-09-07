# 02 — Architecture & Conventions

Technical foundation for SCUM Force: American Mayhem in Godot 4.6. Phase 0 implements everything in this document; later packets build on it without changing it. Where a value is a guess it is marked **(placeholder)** — placeholders are tunable, structure is not.

## 1. Display & pixel-art settings (`project.godot`, set once in Phase 0)

| Setting | Value | Why |
|---|---|---|
| `display/window/size/viewport_width × height` | **640 × 360** | The authored "single screen." Every combat arena is designed against exactly this canvas. |
| `display/window/size/window_width_override × height` | 1280 × 720 | Comfortable default desktop window (2× integer scale). |
| `display/window/stretch/mode` | `canvas_items` | Renders crisp at any window size while game logic stays in 640×360 coordinates. |
| `display/window/stretch/aspect` | `keep` | Letterbox rather than crop — "single screen" means the whole field is always visible. |
| `rendering/textures/canvas_textures/default_texture_filter` | `Nearest` | Pixel art stays sharp, no bilinear smear. |

## 2. View & camera architecture (the screen stack)

The game is a stack of full-screen **screens** with **modals** layered above and a **tooltip layer** above everything. One scene, `main.tscn`, is the permanent root; screens are swapped as children of it.

```
main.tscn (root, never freed)
├── ScreenRoot (Node)            ← exactly one active screen at a time
│     Splash | CharacterSelect | EraMap | Combat | RunSummary
├── ModalLayer (CanvasLayer 10)  ← Shop, Event, Inventory; pause/dim what's beneath
└── TooltipLayer (CanvasLayer 20)← singleton tooltip, topmost, hover + UI-focus driven
```

**Flow** (matches the owner's view map):

```
Splash ──New Game──▶ CharacterSelect ──▶ EraMap ◀──────────────┐
   │                                        │                   │
   └──Continue (load save blob)──▶ EraMap   ├─Combat node──▶ Combat screen ──resolve──┘
                                            ├─Shop node───▶ Shop modal (over EraMap)
                                            ├─Event node──▶ Event modal (over EraMap)
                                            └─Boss node───▶ Combat screen (boss variant)
Run ends (win or full-roster loss) ──▶ RunSummary (full screen) ──▶ Splash
Inventory modal: a self-contained modal (openable from any screen in principle) — MVP wires it to EraMap only
```

**Camera rules:**

- **UI screens** (Splash, CharacterSelect, EraMap, RunSummary) are pure `Control` scenes. No `Camera2D`.
- **Combat** is a fixed-frame single screen: each encounter scene contains one `Camera2D` positioned at the arena center with smoothing off. The camera **never follows the player**. It exists (rather than being omitted) so screenshake and future effects have a hook.
- **Boss encounters** use the same fixed camera, but boss arenas are **authored on a larger canvas** (e.g. 800×450) with the encounter's `Camera2D` zoom set to fit it on screen (`zoom = 0.8` for 800×450) — decided by the owner as the first-pass approach for boss scale, in preference to zooming a 640×360 arena. Accept the slight pixel scaling; revisit if shimmer reads badly in practice.
- **Modals** never move the camera; they render on `ModalLayer` above a paused/dimmed screen.

## 3. Autoloads (global singletons — set once in Phase 0)

Godot autoloads are scripts loaded once at startup and reachable from anywhere. Keep the list minimal:

| Autoload | Responsibility |
|---|---|
| `GameFlow` | Screen routing: `goto_screen(...)`, `push_modal(...)`, `pop_modal()`. Owns ScreenRoot/ModalLayer. Nothing else changes screens. |
| `RunState` | The current run in memory: roster (per-character HP/status), relics/items, cash, arc index, node-map state, RNG seed. Combat reads from and writes back to this. |
| `SaveManager` | Serializes `RunState` + meta-progression to disk; loads on Continue. See §6. |
| `EventBus` | A few global signals (e.g. `character_downed`, `encounter_resolved`) so systems can react without hard references. Use sparingly — prefer local signals. |

## 4. Physics layers — the channel system (frozen after Phase 0)

This is the game's identity, expressed in Godot's 2D physics layers (named in Project Settings → Layer Names → 2D Physics):

| # | Name | Used by |
|---|---|---|
| 1 | `world` | Movement-blocking geometry (walls, structure bodies, arena bounds). Blocks `CharacterBody2D` movement. |
| 2 | `player_body` | Player character bodies. |
| 3 | `enemy_body` | Enemy bodies. |
| 4 | `hurt_low` | Hurtboxes (`Area2D`) of targets reachable by LOW-channel attacks (ground-level units). |
| 5 | `hurt_high` | Hurtboxes of targets reachable by HIGH-channel attacks (units on elevated structures; tall units are on 4 **and** 5). |
| 6 | `block_low` | Structure areas that stop LOW projectiles (any wall/crate with a physical base). |
| 7 | `block_high` | Structure areas that stop HIGH projectiles (tall walls; low walls are NOT on this layer — high shots lob over them). |
| 8 | `pickup` | Minis, exit zone, item pickups (`Area2D` overlap checks). |

**How an attack resolves:** a projectile is an `Area2D` whose `collision_mask` is derived from its channel — LOW masks `hurt_low + block_low`; HIGH masks `hurt_high + block_high`; BOTH masks all four (a BOTH projectile is stopped by whichever blocker it hits first). A unit's **elevation state** (GROUND / ELEVATED / TALL) decides which hurt layers its hurtbox occupies, so moving a unit onto a platform is just a layer flip.

**Worked examples:** a low crate wall (`world + block_low`) stops Johnny's rolled TP but Curt's lobbed cheese sails over it. A dummy on a platform (`hurt_high` only) is untouchable by LOW attacks — that's the "right character for the situation" read. A tall wall (`world + block_low + block_high`) stops everything.

## 5. Data-driven characters & attacks (custom Resources)

> **Superseded (attacks):** the `AttackDef` fields below are replaced by the v2 model in [`04-COMBAT-MODEL.md`](04-COMBAT-MODEL.md) §3 (height profile / lateral motion / wall behavior / on-hit effect). `CharacterDef` and the resource-driven approach still stand.

Custom `Resource` classes are Godot's designer-facing data assets: they appear as editable `.tres` files whose fields show up in the Inspector. **All character and attack tuning lives here** — this is where the owner does balance work without touching code.

```
CharacterDef (resource, resources/characters/*.tres)
  display_name: String
  move_speed: float                 # px/s
  max_half_hearts: int              # health is counted in half-hearts
  primary_attack: AttackDef
  secondary_attack: AttackDef
  sprite/portrait references

AttackDef (resource, resources/attacks/*.tres)
  aim_type: enum { FIXED, FORWARD_VECTOR, FREE_CONE }
  cone_degrees: float               # FREE_CONE only: cursor aim clamped to this arc around facing
  channel: enum { LOW, HIGH, BOTH }
  damage_half_hearts: int
  cooldown_sec: float
  projectile_scene: PackedScene     # or empty for melee/AoE
  projectile_speed: float
  range_px: float
```

One generic player controller reads a `CharacterDef`; characters differ by data, not by bespoke scripts. New character = new `.tres` file.

## 6. Save system

- **What:** two JSON files in `user://` — `save_run.json` (the in-progress run) and `meta.json` (permanent unlocks, later). Both carry a `"version": int` field from day one so future format changes can migrate.
- **When:** `SaveManager.save_run()` fires after every **resolved node** — combat won, shop closed, event resolved. Never mid-combat (encounters run 30–90s; a run resumes at the era map).
- **Run blob shape (v1):** seed, arc index, node-map (nodes, edges, current, cleared), roster array (`id`, `half_hearts`, `max_half_hearts`, `status: active|downed|lost`), relics/items, cash.
- **Continue:** Splash checks for a valid `save_run.json`; loading rebuilds `RunState` and routes to EraMap.

## 7. Input Map (defined once in Phase 0, then frozen)

> **Superseded (controls):** the cursor-facing / mouse-attack model here is replaced by the 8-way-gated, keyboard **+ controller** model in [`04-COMBAT-MODEL.md`](04-COMBAT-MODEL.md) §1. Facing derives from movement, not the mouse.

| Action | Bindings |
|---|---|
| `move_up/down/left/right` | WASD + arrow keys |
| `attack_primary` | Left mouse button |
| `attack_secondary` | Right mouse button |
| `interact` | E |
| `pause_menu` | Esc |
| `open_inventory` | I / Tab |
| `debug_1` … `debug_6` | F1–F6 (gym debug tray; stripped from release builds later) |

Facing = normalized direction toward the mouse cursor. FORWARD_VECTOR attacks fire along facing; FREE_CONE attacks fire toward the cursor clamped to the attack's cone around facing; FIXED attacks ignore aim entirely (pattern defined by the attack, e.g. radial burst).

## 8. Folder structure

```
res://
  autoload/          game_flow.gd, run_state.gd, save_manager.gd, event_bus.gd
  scenes/
    main.tscn        permanent root (§2)
    screens/         splash, character_select, era_map, run_summary
    combat/          gym.tscn, encounter scenes, combat HUD
    characters/      player.tscn (generic controller) + per-character visuals
    enemies/         bag_guy.tscn, target_dummy.tscn
    structures/      low_wall, tall_wall, platform, exit_zone
    ui/              modals (shop, event, inventory), tooltip layer, debug tray
  resources/
    characters/      johnny.tres, curt.tres, ...
    attacks/         tp_roll.tres, long_toss.tres, cheese_wheel.tres, rind_slam.tres
  assets/            sprites, sfx (placeholders: colored shapes are fine pre-art)
  docs/
    plan/            these documents
    systems/         per-system designer explainers (grows with each packet)
```

Scripts are co-located with their scenes (`gym.tscn` + `gym.gd` in the same folder), the standard Godot convention.
