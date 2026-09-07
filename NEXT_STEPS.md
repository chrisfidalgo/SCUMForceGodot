# NEXT_STEPS.md

> Forward-looking build sequence, kept separate from `PROJECT_CONTEXT.md` on purpose — this is scope for the *next* phase of work, not the stable project identity. Expect this file to be replaced by a proper milestone/backlog doc (Jeff-format, see `AGENT_INIT.MD`) once the first phase below is actually underway. Treat everything here as the current best guess at sequencing, not a commitment.

## Why a separate document

The project has a stated habit to avoid: front-loading too much scope into one document and building on a shaky foundation. `PROJECT_CONTEXT.md` holds what's decided; this file holds "what we think comes next," and it's expected to be rewritten or split further as work actually begins.

## Proposed build sequence

1. **Project initialization** — Godot project setup, source control, folder conventions.
2. **Combat testing environment ("the gym")** — the first thing worth building. Purpose: validate core combat feel before any content or map-generation work exists.
   - Player can spawn as at least **two** characters with meaningfully different kits (not just one) — the core bet of this game is that character choice matters, so the gym needs to prove that, not just prove "is moving and shooting fun."
   - Stationary target dummies placed at different heights/channels (low, high, both) to validate the channel-based hit-detection and structure-blocking rules read clearly.
   - A button or debug trigger to spawn a single enemy on demand, to test attack/damage/death in isolation.
   - **Enemies specced 2026-09-07 in `docs/plan/05-ENEMY-MODEL.md`:** three Gain Ground archetypes — Wanderer (moves, no attack), Turret (stationary, fires), Seeker (closes to range, then fires). Pulled earlier in the sequence than originally written, because character choice cannot be evaluated against targets that never shoot back.
   - A debug way to force a character into a "downed" state, to test the mini-rescue/escort loop (pickup, follow, speed penalty at 2+, drop-and-revert-on-death) without needing a full encounter to fail first.
   - This directly mirrors the existing debug-mode pattern already proven in the SCUMForce prototype (`src/modes/debug/DebugMode.ts`, `src/ui/debug/trays/`) — same instinct, new engine.
3. **Minimal fixed node/chapter test harness** — a small, hand-built, *non-random* chain of 3-4 nodes plus a boss, used only to prove the structural plumbing works: node transitions, shared encounter timers, win-by-combat vs. win-by-exit resolution, section-to-boss coalescing. Deliberately built before any procedural/branching map generation, so structural bugs aren't tangled up with map-generation bugs.
4. **Procedural/branching node-map generation** — only after step 3 is proven, build out the real branching structure (arcs drawn from the location pool, node-count ranges, event/merchant node placement).
5. **Design tooling check** — before investing in a custom encounter editor, try authoring a test encounter directly in Godot's native scene editor. Single-screen fixed layouts (enemies, structures, spawn point, exit zone) may not need bespoke tooling at all.
6. **Replace test/placeholder content with real vertical-slice content** — swap the gym's test enemies/targets for real early content once the loop is proven. Bag Guys (reskinned per era) are the intended placeholder-to-real-content bridge, since they're cheap to reskin and already narratively justified as a cross-era faction (see `PROJECT_CONTEXT.md`).

## Explicitly out of scope for this phase

- Multiplayer (any form)
- Procedural map generation (until step 3 above is proven)
- Real reward/relic balancing (placeholder values only)
- Ascension/difficulty ladder tuning
- Currency system implementation
- Event ("???") node content
- Custom encounter-design tooling (unless step 5 shows Godot's native editor isn't sufficient)
