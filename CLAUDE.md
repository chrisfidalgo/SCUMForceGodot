# CLAUDE.md — SCUM Force: Tactics (Godot)

Orientation for any agent or human picking this repo up cold. Keep it short; the
real documentation lives in the files this one points at.

## Read these first, in this order

1. **`docs/plan/01-AGENT-BRIEFING.md`** — who the project owner is, what canon is
   frozen, and the working rules for parallel packets. Non-negotiable starting point.
2. **`docs/plan/00-MASTER-PLAN.md`** — the phase/packet build sequence and where we
   currently are in it.
3. **`docs/plan/02-ARCHITECTURE.md`**, **`03-GYM-SPEC.md`**, **`04-COMBAT-MODEL.md`** —
   the specs. `04` supersedes the combat sections of `02`/`03`.
4. **`docs/systems/*.md`** — designer-facing explainers, one per shipped system.
   Start with `00-godot-primer.md`.

**Design canon lives in a different repo:**
`C:\Users\cfida\Documents\projects\git\SCUMForce-Tactics\PROJECT_CONTEXT.md`
(vision, cast, core loop, tone) alongside `NEXT_STEPS.md` (build sequence) and
`AGENT_INIT.MD` (the `NAME ||` multi-agent command convention — ARTY, JEFF, CID,
DEZ, NADYA, QAIRA, MIRA, PAMELA). Do not invent or alter anything those decide.
This repo implements that canon; it does not own it.

## Running the project — read this before reporting a bug

**F5 (main scene) deliberately dead-ends.** `scenes/main.tscn` boots to
`scenes/screens/placeholder.tscn`, a static label with no input handling and no
route onward. The real Splash → CharacterSelect flow is Phase 2 packet P2a and
has not been built. This is expected, not a regression.

**To play the gym: open `scenes/combat/gym.tscn` and press F6** ("run current
scene"). That is the only playable thing in the project today.

In the gym, press the **`` ` ``** key to open the live tuning panel (sliders over
projectile/height knobs and the active character's attacks; "log values" prints a
snapshot to the console to copy back into the `.tres` files by hand).

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

Headless runs always end with `RID allocations ... were leaked at exit` and
`ObjectDB instances leaked` when a script builds nodes without freeing them.
That is the check script's own doing, not a project fault — ignore it.

Scene/resource files are plain text, so `.tscn` and `.tres` can be read and
edited directly. Prefer that over guessing. Two traps worth knowing:

- An `ext_resource` that no node instances is silently valid — Godot will not
  warn you. That exact mistake once left the tuning panel loaded but invisible.
- Opening the project in the editor re-serializes `project.godot` (adds
  `,"script":null` to input events, drops settings that match engine defaults).
  That noise is harmless, but read the diff before committing it — the input map
  and physics layer names are frozen after Phase 0.

## Where the build actually stands

Phase 0 and Phase 1 Wave 1 are **done and merged**: autoload skeleton
(`GameFlow`/`RunState`/`SaveManager`/`EventBus`), `CharacterDef`/`AttackDef`
resources, the player controller with 8-way movement and mouse aim, the
channel/height projectile model, and the gym with structures and target dummies.

Next per the master plan is **Phase 1 Wave 2** — P1d (health, enemy, downed
state), P1e (rescue/escort/exit loop), P1f (debug tray + combat HUD). The plan
gates that behind the owner playtesting whether Johnny and Curt feel meaningfully
different and whether the channel rules read clearly; the tuning panel exists to
support exactly that session.

## No MCP server is configured

There is no Godot MCP bridge installed and none has ever been used here — all
work goes through direct file editing plus the headless CLI above. If one is
adopted later it will add an `addons/` folder and an `[editor_plugins]` section
to `project.godot`; until then, do not assume live-editor tooling exists.

## Conventions that bite if ignored

- Typed GDScript, `snake_case` files, script named after and beside its scene.
- **Every designer-tunable number is an `@export` or lives in a `.tres`** — the
  owner balances through the Inspector, not by editing code. Magic numbers in
  scripts are a defect here, not a style nit.
- Cross-cutting combat values that must change *while the game runs* go on
  `CombatTuning` (`scenes/combat/combat_tuning.gd`) as `static var`s instead.
  Per-attack numbers stay on `AttackDef`.
- Signals for decoupling; a child never reaches up the tree to call its parent.
- Each new system ships a `docs/systems/<system>.md` explainer for a designer.
