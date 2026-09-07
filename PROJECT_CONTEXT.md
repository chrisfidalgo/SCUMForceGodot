# PROJECT_CONTEXT.md

> **Canonical agent context file.** It lives at the root of the game repo, alongside the code it describes; read it before giving project-specific guidance. This is a new, separate project from the SCUMForce (Vite/PixiJS/React swarm-survivor) prototype — it shares world, cast, and art direction, but not code, mechanics, or codebase.

## Project Name

**SCUM Force: American Mayhem.** Settled 2026-09-07, replacing the provisional working title "SCUM Force: Tactics". The Godot repo folder is `sf-godot`.

## Vision

A whacky cast of characters is thrown into a journey across time. They use unconventional weapons — toilet paper, blue cheese, wrenches — to defeat dinosaurs, medieval knights, modern forces, and anything else the team invents. Each run is a unique series of nodes/encounters: mostly single-screen tactical combat, but some are events, shopkeepers, or other happenings.

**Player fantasy:** single-screen tactical mastery. Read the situation, pick the right character and attack channel for it, escort fallen teammates to safety, and survive escalating stakes across a roguelite run.

This project exists because an earlier prototype (SCUMForce, a Vampire-Survivors-style swarm game reusing this same cast) didn't hold onto the thing that made the original inspiration interesting: **Gain Ground's** character-suited-to-situation tactics. That identity doesn't survive in a multidirectional swarm game, so this is a deliberate new direction, not an iteration on the old one.

## Genre / Type

2D pixel art, top-down, tactical action, roguelite structure. Real-time (not turn-based) — the vision is faster-paced than Gain Ground but not frantic/twitch-reflex-driven; single-screen encounters are meant to stay readable and methodical.

**Inspirations:**
- **Gain Ground** — moment-to-moment combat and tactics (character-suited-to-situation, height/channel-bound projectiles, forced vs. free aim)
- **Slay the Spire** — map and meta-progression structure (branching node-map, run-based rewards, ascension-style difficulty)
- **Into the Breach** — design principles (full-information tactical decisions, small-team-buildable scope, no unwinnable-by-design states)

Explicitly **not** using an elemental/alchemical combo system (status effects interacting across characters) — that idea was considered for this project and deliberately deferred to a possible future game instead.

## Target Platform

PC / Steam. Desktop, real-time single-screen encounters. Local multiplayer (1-2 players sharing a single roster, echoing the original Gain Ground arcade cabinet) is a stated long-term goal but explicitly **not** MVP scope — see Open Questions.

## Core Loop / Key Feature

**Run structure:** At the start of a run, the player picks 1-3 characters into their roster. A run consists of 3 arcs, each drawn from a pool of possible eras/locations (currently: 2 "ancient history" options, 2 "modern history" options, 1 "future" option — a run sees 3 of these 5, not all of them, which keeps content reusable across replays). Each arc is a branching node-map (~6-9 combat encounters + 2-3 event/merchant nodes, converging to a boss). Target pacing: ~15-20 minutes per arc, ~45-60 minutes per full run.

**Combat encounter (single screen):**
1. Player selects one character from the current roster; they spawn at the bottom of the field.
2. The player moves and attacks in real time. Every character has a primary and secondary attack; attacks are constrained by aim (fixed-direction / forward-vector / free-aim within an angle) and by **collision channel** (high, low, or both) — the direct carryover of Gain Ground's identity.
3. Structures (walls, barricades) block or require specific channels to bypass — an enemy on a high structure needs a high attack to reach; an enemy behind a wall can be preemptively defeated with the right channel. This is the core "right character for the situation" design space, and it is a **soft** system: covering both channels earns a payoff, but no encounter may ever *require* a channel/character combination the player doesn't have access to. Every boss must be killable by every character — no Gain-Ground-final-boss-style hard gates.
4. Taking damage costs half-hearts (see Health, below). A character reduced to 0 health "dies" and becomes a rescuable mini on the field.
5. Colliding with a mini causes it to follow the player. Escorting exactly 1 mini has no penalty; escorting 2+ applies a movement speed penalty — a deliberate risk/reward dial (Genesis Gain Ground's hard 1-mini cap was judged as padding, not depth). If the escorting character dies before reaching the exit, the mini falls back to lying in place — re-rescuable later, not lost.
6. Reaching the marked exit zone marks the current character "survived" and removes them from this encounter's selection pool (the player must then pick their next character). An encounter is won by clearing all enemies, or by getting all characters through the exit — both paths open simultaneously under a shared timer. If the whole roster is defeated with none surviving, the run ends. Boss nodes have no exit option; only a full clear wins.

**Health (proposed starting values, expect tuning):** hearts/half-hearts as the visual model, at a much lower scale than the SCUMForce swarm prototype since these encounters run ~30-90 seconds, not several minutes of attrition.
- Assassin-type archetype: 2 hearts (4 half-heart hits)
- Balanced archetype: 3 hearts (6 hits)
- Tank archetype: 4-5 hearts (8-10 hits)
- Standard hits cost half a heart; heavy/boss attacks may cost a full heart or more.
- No mid-combat HP regen — encounters are too short for it to matter. Recovery happens structurally instead (rest/shop nodes, reward options like "heal to full" or "+1 max heart").
- Shield/armor (temporary damage-absorbing buffer) is sourced from between-encounter rewards/relics rather than mid-encounter pickups, and is proposed to refill at the start of every encounter rather than persisting depleted across the whole run.

**Rewards (proposed categories, not balanced):** direct stat-ups (max hearts, move speed, attack damage/range/fire-rate); mechanical modifiers/relics (change an attack's channel access, aim constraint, or add a utility like a dash — this is the game's answer to VS's evolution-style build depth, without an elemental system); roster unlocks (new permanent characters via meta-progression, in addition to in-run mini-rescue); boss rewards (a run-persistent passive/blessing, bigger than a stat bump); meta-progression (cosmetics, new starting relic options, new difficulty tier on a run win).

**Difficulty/ascension (proposed direction, untested at the top end):** rather than purely scaling enemy numbers, escalate via **death-permanence** — easiest tier: a defeated character is only unavailable for that encounter; harder tiers progressively remove the guarantee of getting them back (reappear later on the map as a rescue detour → maybe acquirable via a rarer mechanism → permanently lost for the run). Easiest tier has no meta-reward but unlocks the next, higher-stakes tier.

## Current Milestone

**In production on the gym (`NEXT_STEPS.md` step 2).** Design docs and code now live together in this one repo (Godot 4.6.3, GDScript) — start at `CLAUDE.md`, then `docs/plan/01-AGENT-BRIEFING.md`.

Shipped as of 2026-09-07:

- **Step 1 (project initialization) — done.** Godot project, source control, folder conventions, four autoloads (`GameFlow`/`RunState`/`SaveManager`/`EventBus`), `CharacterDef`/`AttackDef` resources, frozen input map and physics layers.
- **Step 2 (the gym) — built.** The arena runs with structures, elevated dummies, an 8-way player controller, and the channel/height projectile model that carries this game's core identity. On top of that: half-heart health, three enemy archetypes (wandering, stationary-shooting, and seek-then-fire) whose shots obey the same channel rules the player's do, the downed-mini rescue/escort loop with its 2+ speed penalty, a debug tray, a combat HUD, a channel-visualisation overlay, and a live in-play tuning panel for balancing without leaving play mode.
- **Not yet built:** the screen flow, so the game still boots to a placeholder and the gym must be launched directly (Phase 2, packet P2a).

**The gate before anything else:** the owner playtests whether Johnny and Curt feel meaningfully different and whether the channel rules read clearly. That is the core bet of this game, and steps 3+ stay parked until it is answered. The gym now contains everything needed to answer it.

## Technical Stack

**Godot** (engine choice driven by no licensing cost and a deliberate goal to learn Godot; some prior team exposure to Godot exists but not deep architectural familiarity — this is itself one of the project's stated goals). This is a distinct codebase from the SCUMForce prototype (Vite + TypeScript + React + PixiJS + Zustand, ECS) — reuse between the two projects is at the world/cast/art level only, not code or systems.

## Art Direction

2D pixel art, top-down, single-screen encounter scale (as opposed to the swarm-scale camera of the SCUMForce prototype). Carries forward SCUM Force's established tone: 90s-arcade energy, campy, loud, juicy, intentionally over the top; strong silhouettes; vibrant saturated palettes; avoid muted/grimdark/photorealistic references.

**Early placeholder strategy:** use **Bag Guys** (BAG CORP's disposable henchman faction — paper bag on head, black suit) as the default fodder enemy across every era, reskinned per zone (caveman outfit, knight outfit, modern business suit, etc.). This is both a cost-saver (one archetype, many reskins, instead of a wholly distinct enemy roster per era) and a narrative hook (BAG CORP as an organization with reach across every time period the crew visits).

## Narrative Premise

Full reuse of the existing SCUM Force world:

- **Hub:** Smoke N' Bowl, a bowling alley (Americana, campy, absurd).
- **Inciting event:** something tears the bowling alley apart and scatters the crew across time (Wizard-of-Oz-style), enabling a wide variety of eras/settings.
- **Playable cast:** Gary/SCUM (bowling league leader, bowling ball), Johnny/Weenie (janitor, toilet paper, fast/low-HP), Curt/Curly (cook, bleu cheese, slow/high-HP), Stanley (maintenance, wrench), Angelo (unlockable elder archetype, classic bowling ball).
- **Villains:** Mr. Sir (BAG CORP leader, primary antagonist), Bag Guys (BAG CORP's disposable army — see Art Direction above for their new role as cross-era fodder), Lobstersharktopus Man (BAG CORP's engineered weapon, boss-tier threat).
- **Tone:** absurd, campy, Americana-inspired, cartoon violence — heroes lean on silly objects rather than guns/traditional weapons, even though villains may use them.

Treat this section as a summary; expand independently if this project's narrative needs diverge from the SCUMForce prototype's.

## Production Constraints

- Small/solo-oriented team; prototype-first, rapid iteration prioritized over polish.
- Before building custom encounter/map design tooling, try Godot's native scene editor — each encounter is a fixed single-screen layout (enemies, structures, spawn point, exit zone), which the built-in editor may already cover.
- Deliberately avoid overscoping this document: anything not yet decided lives in Open Questions below or in `NEXT_STEPS.md`, not as an assumed requirement here. New milestone-scoped documents should be created one at a time, only when that phase of work actually begins (see Jeff's MVP/milestone format in `AGENT_INIT.MD`).

## Known Risks

- **Per-era content cost still exists at the zone/archetype level**, even after moving away from bespoke campaign levels — mitigated (not eliminated) by the Bag Guys reskin strategy.
- **"Real-time but methodical" is a genuine, unresolved design tension.** Real-time systems drift toward twitch/reflex play unless deliberately paced (telegraphs, cooldowns, deliberate movement speed). Needs dedicated character-move ideation and playtesting before it can be called solved.
- **Ascension ladder's top end is untested.** At the harshest death-permanence tier, if the roster can only shrink with no mid-run replenishment, a run could spiral toward an unwinnable state rather than sustained tension — worth deciding on purpose, not discovering in playtesting.
- **The health/heart model is a hypothesis carried over from the SCUMForce swarm prototype**, not yet validated for this game's shorter, higher-stakes single-screen encounters.

## Open Questions

- **Multiplayer specifics** — 1-2 players, shared roster (odd roster count means one player sits out until a character frees up) confirmed as the target, but sit-out UX, input handling, and rebalancing per player count are all undecided. Treated as post-MVP.
- **Input scheme / per-character move design** — not all characters necessarily share a "simple primary / precision-aimed secondary" template; needs dedicated character-move ideation and playtesting, not a paper decision.
- **Currency split** — likely a mid-run currency ("cash") distinct from a persistent meta-currency (gold bars/diamonds, tentative), but unconfirmed. Angelo's previously-noted 9,999-coin unlock exists only in world-building/data right now, not as a tested mechanical precedent.
- **Event ("???") node content** — likely written events with light art; scope deliberately not fleshed out yet to avoid overscoping.
- **Boss design specifics beyond "killable by every character, no exit"** — e.g., whether/how a boss might occupy or shift between channels to test the tactical system more directly, is an open opportunity, not yet designed.
- **Exact archetype/enemy budget per era** — not yet set.

## Current Priorities

Validate core combat feel (multi-character switching, channel-based tactics, mini-rescue/escort) in an isolated testing environment before writing any procedural map/node generation logic or committing to real content. See `NEXT_STEPS.md`.
