# Arena, Structures & Dummies (packet P1b)

The gym (`scenes/combat/gym.tscn`) is the 640×360 combat-test arena: a plain
floor, arena-bound walls, an exit zone, a sampler of the three structure
types, and a row of three target dummies. This doc explains how the channel
system (02-ARCHITECTURE.md §4) is expressed here in nodes you can click and
inspect, and how to test it by hand before the player/projectiles arrive.

## Two node types that do the physics work here

- **`StaticBody2D`** — a solid, immovable physics body. Anything on the
  `world` layer (1) physically blocks a `CharacterBody2D` from walking
  through it. Used for arena walls and the wall structures' bodies.
- **`Area2D`** — an overlap *detector*, not a blocker. It never stops
  movement; it just reports "something entered me." Used for the exit zone,
  every structure's block layer, and every dummy's hurtbox. This is what
  makes the channel system possible: a projectile is also an `Area2D`, and
  two `Area2D`s only "see" each other if one's `collision_mask` includes the
  other's `collision_layer` — a pure Inspector-level rule, no code needed to
  decide who blocks whom.
- **`Marker2D`** — an invisible locator point (shows only as a cross in the
  editor). `PlayerSpawn`, at the bottom-center of the arena, marks where a
  character enters — no collision, no visual, just a coordinate.

## The layout

```
Gym (640×360, fixed Camera2D at 320,180)
├── Floor, Bounds (4 boundary StaticBody2D walls on `world`)
├── ExitZone            — top edge
├── PlayerSpawn          — bottom-center Marker2D
├── Structures (left-of-center)
│   ├── LowWall
│   ├── TallWall
│   └── Platform          — hosts the ELEVATED dummy on top
└── Dummies (right-of-center row)
    ├── DummyElevated     — sits on Platform
    ├── DummyGround
    └── DummyTall
```

## Structures — one Inspector row per behavior

Every structure is its own scene (`scenes/structures/`), so its collision
layers are set once and reused everywhere it's instanced.

| Structure | Blocks movement? | Blocks LOW shots? | Blocks HIGH shots? |
|---|---|---|---|
| `low_wall.tscn` | Yes (`StaticBody2D` on `world`) | Yes (`Area2D` on `block_low`) | No — HIGH shots lob over |
| `tall_wall.tscn` | Yes (`StaticBody2D` on `world`) | Yes (`Area2D` on `block_low`) | Yes (same `Area2D`, also on `block_high`) |
| `platform.tscn` | No — it's a riser, not a wall | Yes (`Area2D` on `block_low`) | N/A (it has no `hurt` layer itself; it just visually hosts an elevated dummy) |

Structures never implement `receive_hit()` — that method belongs only to
things that can be *damaged*. A structure's `Area2D` exists purely to be
detected by a projectile's `collision_mask`; there is nothing to call on it.

## Dummies — elevation is a layer flip

`scenes/enemies/target_dummy.tscn` + `target_dummy.gd` (`class_name
TargetDummy`) is the reusable dummy. Select any dummy in the Scene dock and
its **Elevation** dropdown (Inspector) is the only thing that changes between
the three instances in the gym — everything else about the scene is
identical:

| Elevation | Hurtbox (`Area2D`) sits on | Hit by |
|---|---|---|
| GROUND | `hurt_low` only | LOW and BOTH attacks |
| ELEVATED | `hurt_high` only | HIGH and BOTH attacks |
| TALL | `hurt_low` **and** `hurt_high` | every attack |

The dummy applies its elevation in `_ready()` by setting the Hurtbox's
`collision_layer` — "moving a unit onto a platform is just a layer flip"
(02-ARCHITECTURE.md §4): nothing about combat code needs to know a dummy is
elevated, only its physics layer changes.

### The shared hurtbox contract

Every dummy exposes exactly:

```
func receive_hit(damage_half_hearts: int) -> void
func reset_counter() -> void
```

`receive_hit()` is the one method the projectile packet (P1c) calls on
overlap. Calling it: flashes the dummy (briefly recolors it, then eases back
to its base color over `flash_duration_sec`), spawns a floating `-N` label
that rises and fades over `damage_number_duration_sec`, and increments the
on-dummy hit counter label (which also shows the dummy's elevation, e.g.
`"TALL — Hits: 3"`). Dummies never lose HP and never die — they're a
measuring stick, not an enemy. `reset_counter()` zeroes the counter (wired to
the gym's F4 debug-tray button in a later packet).

### Inspector-tunable knobs (all on `TargetDummy`, no script edits needed)

`elevation`, `flash_color`, `flash_duration_sec`, `damage_number_rise_px`,
`damage_number_duration_sec` — every one is an `@export` var visible when you
select a dummy instance.

## Exit zone

`scenes/structures/exit_zone.tscn` (`class_name ExitZone`) is an `Area2D` on
the `pickup` layer (8), masked to detect the `player_body` layer (2), marked
with a translucent green `ColorRect` at the top of the arena. On overlap it
prints `"survived: <character name>"` to the console — that's the full
implementation for now; banking escorted minis and real win/loss resolution
are Phase 2.

## How to test by hand (no player/projectiles yet)

The player and projectiles are built by other packets and aren't in this
scene yet, so hand-verification has to stand in for playtesting:

1. Open `scenes/combat/gym.tscn` and press **F6** (run this scene). It
   should boot with no errors in the debugger and show the arena: dark
   boundary walls, a low wall + tall wall on the left, a platform with a
   dummy on it near center, and two more dummies to the right.
2. Click any dummy in the Scene dock, open the **Remote** tab in the Scene
   dock while the game is running, and call `receive_hit(1)` from the
   Remote Inspector's context menu (or temporarily wire a debug key) to
   confirm the flash, floating number, and counter all fire.
3. Click each structure's `Area2D` (or `StaticBody2D`) node and check its
   **Collision → Layer** row in the Inspector against the tables above.
4. Walk (once the player exists) into the top of the arena — the console
   should print `survived: <name>` when you cross into the green zone.

## Placeholders

All colors, sizes, and positions are flat placeholder shapes (`ColorRect`s) —
no real art. Wall thickness (16px), structure sizes, and arena layout
positions are hand-picked to keep the sampler readable, not final level
design. The floating damage number and hit-count label use Godot's default
font/size.
