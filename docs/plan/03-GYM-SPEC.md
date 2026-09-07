# 03 — Gym Spec (Phase 1, the first build target)

The gym is a combat-testing environment, not a game level. Its job is to prove the core combat feel — character contrast, channel-based tactics, and the downed/rescue loop — before any content or map-generation work exists. It mirrors the debug-mode instinct proven in the earlier SCUMForce prototype, rebuilt for Godot.

Everything here that is a number is a **placeholder** for the owner to tune in the Inspector (see `02-ARCHITECTURE.md` §5 — all of it lives in `.tres` resources or `@export` vars).

## 1. The scene (`scenes/combat/gym.tscn`)

One 640×360 arena, fixed camera at center, plain placeholder-tile floor with arena-bound walls. Laid out in the Godot scene editor (this doubles as the Phase-2 check on whether native editing suffices for encounter authoring). Contents:

- **Player spawn marker** at bottom-center (matching real encounters: characters enter from the bottom).
- **Exit zone** (`Area2D` on `pickup` layer) at top edge, visibly marked. Functional: a character entering it banks any escorted minis and logs "survived" to console/on-screen — no full win/loss logic yet (that's Phase 2's harness).
- **Structure sampler** (left half): one **low wall** (`world + block_low` — blocks movement and LOW shots, HIGH shots lob over), one **tall wall** (`world + block_low + block_high` — blocks everything), one **platform** with an elevated dummy on top.
- **Dummy row** (right half): three stationary target dummies — GROUND (`hurt_low`), ELEVATED on the platform (`hurt_high`), TALL (`hurt_low + hurt_high`). Dummies flash on hit, show floating damage numbers, and display a running hit counter; they never die, a debug button resets counters.
- **Debug tray** (bottom-left UI panel, see §5).

## 2. The two characters

> **Superseded:** the kits and aim types here are replaced by [`04-COMBAT-MODEL.md`](04-COMBAT-MODEL.md) §4 (starters Johnny Cool / Curt / Scum; no cursor cone). Retained for history.

Both are driven by the same generic player controller reading a `CharacterDef` resource. The pair deliberately covers **all three aim types** and **all three channels** between four attacks — that's the coverage the gym must demonstrate.

### Johnny "Weenie" — fast and fragile (assassin archetype)

| Field | Value (placeholder) |
|---|---|
| Move speed | 150 px/s |
| Health | 2 hearts (4 half-heart hits) |
| **Primary — "TP Roll"** | FORWARD_VECTOR · **LOW** · 1 half-heart · 0.25s cooldown · projectile speed 320 · range 240px. A fast-rolling TP projectile along his facing — his bread and butter, stopped by any low blocker. |
| **Secondary — "Long Toss"** | FREE_CONE 120° · **HIGH** · 2 half-hearts · 1.2s cooldown · lobbed arc · range 200px. A thrown TP wad that sails over low walls and reaches elevated targets — his answer to what the roll can't touch. |

### Curt — slow and tanky

| Field | Value (placeholder) |
|---|---|
| Move speed | 90 px/s |
| Health | 4 hearts (8 half-heart hits) |
| **Primary — "Cheese Wheel"** | FREE_CONE 90° · **BOTH** · 2 half-hearts · 0.8s cooldown · projectile speed 220 · range 220px. A hurled wheel that hits any elevation but is stopped by the first blocker of either channel. |
| **Secondary — "Rind Slam"** | FIXED (radial burst around self, radius 48px) · **LOW** · 3 half-hearts · 2.5s cooldown. A ground slam — no aiming at all, pure positioning. |

**The intended read the gym must produce:** Johnny shreds ground targets in the open but has to work for elevated ones; Curt hits everything but slowly and can't out-position danger. If a playtester can feel that difference inside two minutes, the core bet is validated.

## 3. Test enemies

> **Superseded 2026-09-07 by `05-ENEMY-MODEL.md`.** The single chase-only Bag
> Guy below was the original minimum. The gym now targets three archetypes —
> Wanderer, Turret, Seeker — because character choice cannot be evaluated
> against an enemy that never shoots back. The Bag Guy survives as the
> Wanderer, with its beeline chase replaced by aimless wandering. Build from
> `05`; the paragraph below is kept for the stat baseline only.

### 3.1 Original single-enemy baseline (historical)

One enemy type, spawned on demand only (no waves): walks straight toward the player at 70 px/s, GROUND elevation, 2 half-hearts of HP, deals 1 half-heart on body contact with a 0.5s per-target damage cooldown, dies with a simple pop. No attack patterns, no AI states beyond "chase" — it exists to test damage-in, damage-out, and death in isolation.

## 4. Downed / mini / escort loop

- A character at 0 half-hearts becomes a **mini**: a small pickup-sized version lying where they fell (`Area2D`, `pickup` layer).
- The active character colliding with a mini attaches it as a **follower** (trailing chain behind the player).
- Escorting **1 mini: no penalty. 2+ minis: −25% move speed (placeholder)** — the risk/reward dial from the design doc.
- If the escorting character goes down, followed minis **drop in place**, re-rescuable — never lost.
- Minis delivered to the exit zone are banked (logged; real recovery rules are Phase 2+).
- Character swap (debug tray) lets you play the "next roster member" after a down, approximating the real encounter flow.

## 5. Debug tray (hotkeys F1–F6 + on-screen buttons)

| Key | Action |
|---|---|
| F1 | Spawn one Gym Bag Guy at a random edge point |
| F2 | Force the current character into the downed/mini state |
| F3 | Swap to the other character (spawns them at the spawn marker if not present) |
| F4 | Reset: clear enemies/minis, reset dummy counters, restore HP |
| F5 | **Channel visualization overlay**: tints every hurtbox and blocker by channel (e.g. LOW = orange, HIGH = blue, BOTH = purple) so the channel rules are legible at a glance — this is also a prototype of possible player-facing readability UI |
| F6 | Toggle invincibility |

The tray is a self-contained UI scene (`scenes/ui/debug_tray.tscn`) so it can drop into any future encounter scene unchanged.

## 6. Combat HUD (minimal)

Hearts display for the active character (half-heart granularity), active character name, both attack cooldown indicators, escorted-mini count. Placeholder art throughout.

## 7. Acceptance criteria (the integration pass checks every box)

1. Gym scene runs standalone (F5 from `gym.tscn`), no errors in the debugger.
2. WASD movement + mouse facing works; character speed matches their `CharacterDef`.
3. All four attacks fire with correct aim behavior: TP Roll along facing only; Long Toss and Cheese Wheel toward cursor, clamped to their cones; Rind Slam ignores the cursor.
4. Channel matrix is correct — verified against the dummy row with the F5 overlay on:
   - LOW attacks hit GROUND and TALL dummies, never the ELEVATED one.
   - HIGH attacks hit ELEVATED and TALL, never GROUND.
   - BOTH hits all three.
5. Structure matrix is correct: low wall stops TP Roll but not Long Toss; tall wall stops everything; platform blocks LOW shots from passing while its dummy takes HIGH hits.
6. F1 enemy chases, damages on contact (half-heart with cooldown), takes damage, dies at 0.
7. HP reaching 0 (or F2) produces a mini at the character's position; swap (F3) continues play.
8. Mini pickup, follow-chain, 2+ escort speed penalty, drop-on-death, and re-rescue all behave per §4.
9. Exit zone banks escorted minis and logs the character as survived.
10. Every tuning number listed in §2–§4 is editable in the Inspector without opening a script.
11. All debug tray functions work from both hotkey and button.
12. `docs/systems/` contains explainers for: player controller & aiming, channel/collision system, health & downed/mini loop, and the debug tray.

## 8. Explicitly NOT in the gym

Encounter timer, win/loss resolution, roster selection UI, enemy waves or AI beyond chase, rewards, any real art, sound, save/load. All Phase 2+.
