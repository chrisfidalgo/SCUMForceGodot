# CLAUDE.md — SCUM Force: American Mayhem

Orientation for any agent or human picking this repo up cold. Keep it short; the
real documentation lives in the files this one points at.

Design docs and code live together in this single repo. There is no external
canon folder — if you find a reference to one, it is stale.

## Read these first, in this order

1. **`PROJECT_CONTEXT.md`** (root) — canonical design source: vision, cast, core
   loop, tone, risks, open questions. Do not invent or alter what it decides.
2. **`docs/plan/01-AGENT-BRIEFING.md`** — who the project owner is, what is
   frozen, and the working rules for parallel packets. Non-negotiable.
3. **`docs/plan/00-MASTER-PLAN.md`** — phase/packet build sequence and where we
   currently are in it. `NEXT_STEPS.md` (root) is the coarser version it refines.
4. **The specs:** `02-ARCHITECTURE.md`, `03-GYM-SPEC.md`, `04-COMBAT-MODEL.md`,
   `05-ENEMY-MODEL.md`. **`04` supersedes the combat sections of `02`/`03`**, and
   **`05` supersedes `03` §3.**
5. **`docs/systems/*.md`** — designer-facing explainers, one per shipped system.
   Start with `00-godot-primer.md`.

`AGENT_INIT.MD` (root) defines the `NAME ||` multi-agent command convention
(ARTY, JEFF, CID, DEZ, NADYA, QAIRA, MIRA, PAMELA).

## Running the project — read this before reporting a bug

**F5 (main scene) deliberately dead-ends.** `scenes/main.tscn` boots to
`scenes/screens/placeholder.tscn`, a static label with no input handling and no
route onward. The real Splash → CharacterSelect flow is Phase 2 packet P2a and
has not been built. This is expected, not a regression.

**To play the gym: open `scenes/combat/gym.tscn` and press F6** ("run current
scene"). That is the only playable thing in the project today.

In the gym, press the **`` ` ``** key for the live tuning panel — sliders over
the projectile/height knobs and the active character's attacks, plus a "log
values" button that prints a snapshot to the console to copy back into the
`.tres` files by hand. Swap characters via the player's `character_def` in the
Inspector; there is no swap hotkey until P1g.

## Verifying without opening the editor

The engine binary is not on `PATH`:

```
C:\Users\cfida\Documents\Godot_v4.6.3-stable_win64_console.exe
```

Use the `_console.exe` variant — the plain one detaches and prints nothing.

```sh
# Does the project boot clean? (no output = no errors)
Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit-after 120

# Run a throwaway check script (extends SceneTree, call quit() when done)
Godot_v4.6.3-stable_win64_console.exe --headless --path . --script check.gd
```

Headless runs end with `RID allocations ... were leaked at exit` whenever a check
script builds nodes without freeing them. That is the script's own doing, not a
project fault — ignore it.

Scene and resource files are plain text, so `.tscn` and `.tres` can be read and
edited directly. Prefer that over guessing. Two traps worth knowing:

- An `ext_resource` that no node instances is silently valid — Godot will not
  warn you. That exact mistake once left the tuning panel loaded but invisible.
- Opening the project in the editor re-serializes `project.godot` (adds
  `,"script":null` to input events, drops settings that match engine defaults).
  That noise is harmless, but read the diff before committing it — the input map
  and physics layer names are frozen after Phase 0.

There is no MCP server configured and none is planned for now; work through
direct file editing plus the CLI above. The project targets Godot 4.6.x and
there is no pending engine upgrade — do not raise either as a concern.

## Where the build actually stands

**Done:** Phase 0, Phase 1 Wave 1, and **Phase 1 Wave 2**. The gym is now a
playable loop, not a shooting range:

- Autoloads, `CharacterDef`/`AttackDef` resources, 8-way player controller,
  channel/height projectile model, structures and elevated dummies (Wave 1).
- Half-heart health with i-frames, and script-level factions so the height-based
  hurt layers can still tell friend from foe (**P1d**).
- Three enemy archetypes — Wanderer / Turret / Seeker — firing through the
  player's own `AttackSpawner`, so enemy shots obey the channel rules and a low
  wall is real cover (**P1e**).
- Going down leaves a rescuable mini; pickup, follow-chain, the 2+ escort speed
  penalty, drop-on-death and exit banking (**P1f**).
- Debug tray (F1–F6), combat HUD, and the channel-visualisation overlay
  (**P1g**).

**Next: the owner's core-feel playtest**, which the master plan gates Phase 2
behind — *does Johnny feel meaningfully different from Curt, and do the channel
rules read clearly?* Everything in Wave 2 exists to make that answerable. Tune
via the Inspector and the in-play `` ` `` panel; nothing new should be built
until that question has an answer.

## Conventions that bite if ignored

- Typed GDScript, `snake_case` files, script named after and beside its scene.
- **Every designer-tunable number is an `@export` or lives in a `.tres`** — the
  owner balances through the Inspector, not by editing code. Magic numbers in
  scripts are a defect here, not a style nit.
- Cross-cutting combat values that must change *while the game runs* go on
  `CombatTuning` (`scenes/combat/combat_tuning.gd`) as `static var`s instead.
  Per-attack numbers stay on `AttackDef`.
- **Anything with knobs worth feeling out joins the `tunable` group** and
  implements `get_tuning_label()` / `get_tuning_attacks()` / `get_tuning_spec()`.
  Its section then appears in the in-play `` ` `` panel automatically, with no
  edit to `tuning_panel.gd` — which is what keeps parallel packets off a shared
  file. See `docs/systems/tuning-panel.md`.
- **Enemies reuse the player's pipeline.** `AttackSpawner.spawn_attack()` takes
  any `source`; enemy attacks are `.tres` files like the player's, and enemy
  projectiles obey the same channel rules — which is what makes walls into cover.
  See `05-ENEMY-MODEL.md` §3 before writing any enemy attack code.
- Signals for decoupling; a child never reaches up the tree to call its parent.
- Each new system ships a `docs/systems/<system>.md` explainer for a designer.
