# 01 — Agent Briefing (READ FIRST)

Every implementing agent reads this file before touching the project. It covers who you're building for, what canon you must respect, and the working rules that keep parallel agents from colliding.

## Who you are working for

The project owner is a **seasoned game developer with a game systems design background**. They are **not an engineer by trade** — they have coding coursework and certifications, but they read visual structures (scene trees, inspectors, node graphs, data tables) far more fluently than code. They are **new to Godot** specifically: its node/scene model, signals, autoloads, and resource system are unfamiliar territory.

This changes how you deliver work:

1. **Explain Godot concepts on first use.** The first time your hand-off summary mentions a signal, an autoload, an `Area2D`, or a custom `Resource`, add one plain-language sentence about what that thing is and why it was the right tool. Don't assume the reader knows why an `Area2D` differs from a `StaticBody2D`.
2. **Make tuning visual, not textual.** Every gameplay number a designer would want to touch (speeds, damage, cooldowns, HP, cone angles, escort penalties) must be an `@export` variable or live in a `.tres` resource file, editable in the Godot Inspector — never a magic number buried in a script. This is the single most important convention in the project: the owner will do balance work through the Inspector.
3. **Ship an explainer with each system.** Each work packet that introduces a new system delivers a short `docs/systems/<system>.md` (half a page to a page) written for a designer: what the system does, which scene/nodes own it, which knobs are tunable and where to find them in the editor, and how to test it by hand. This is where the teaching lives — keep the code itself clean rather than over-commented.
4. **Prefer scenes and the editor over code where Godot allows it.** If a layout, animation, or configuration can live in a `.tscn`/`.tres` the owner can open and inspect visually, put it there instead of constructing it in script.

## Canon you must respect

- **Design source of truth:** `C:\Users\cfida\Documents\projects\git\SCUMForce-Tactics\PROJECT_CONTEXT.md`. Do not invent or alter mechanics, cast, tone, or structure that document already decides. If your packet seems to require contradicting it, stop and flag it instead.
- **Build sequence:** `NEXT_STEPS.md` in that same folder, refined by `00-MASTER-PLAN.md` here. Do not build ahead of the current phase: no procedural map generation, no multiplayer, no real economy/balance, no ascension tuning until the plan reaches them. Placeholder values are expected and must be labeled as placeholder.
- **Key identity to protect:** attacks constrained by aim type (fixed / forward-vector / free-aim-in-a-cone) and collision channel (high / low / both), with structures that block per channel. This is a **soft** system — a payoff for covering both channels, never a hard gate. If an implementation choice would make a channel mandatory to win, it's wrong.

## Decided (do not re-litigate)

| Decision | Value |
|---|---|
| Engine | Godot 4.6, GL Compatibility renderer |
| Language | GDScript (typed), no C#, no plugins without approval |
| Base resolution | 640×360, `canvas_items` stretch, nearest-neighbor filtering |
| Input (first target) | Keyboard + mouse (WASD move, cursor aim); controller is a later packet |
| First playable pair | Johnny "Weenie" (fast/fragile) + Curt "Curly" (slow/tanky) — kits in `03-GYM-SPEC.md` |
| Save cadence | Serialize run state to a JSON blob after every resolved node (encounter/shop/event) |

## Working rules for parallel agents

- **`project.godot`, the Input Map, and physics layer names are frozen after Phase 0.** They are set once by the setup packet (see `02-ARCHITECTURE.md`). Editing them in a feature packet causes merge conflicts in the worst file to merge — if your packet truly needs a new input action or layer, flag it to the orchestrator instead of editing.
- **One packet, its own scenes.** Packet boundaries are drawn so that no two parallel packets edit the same `.tscn` or `.gd`. Stay inside your packet's file list; if you need to touch a shared file, flag it.
- **Keep the gym runnable.** `scenes/combat/gym.tscn` must run (**F6** — "run current scene" — with that
  scene open) at the end of every packet. Note F5 runs the *main* scene, which
  boots to a placeholder and does not reach the gym until Phase 2's P2a lands. A packet that leaves the project in a broken state is not done.
- **Integration points are real work.** After each wave of parallel packets, one integration pass runs the gym against the acceptance criteria in `03-GYM-SPEC.md` before the next wave starts.
- **Commit style:** small commits, present-tense summaries, one packet per branch if branching is used.

## Code conventions (details in 02-ARCHITECTURE.md)

- Typed GDScript everywhere (`var speed: float`, typed function signatures).
- `snake_case` file names; script co-located with and named after its scene (`gym.tscn` + `gym.gd`).
- `class_name` for anything reused across scenes; signals (with typed payloads) for decoupling — a child never reaches up the tree to call its parent.
- Comments only for constraints the code can't express; teaching goes in `docs/systems/`.
