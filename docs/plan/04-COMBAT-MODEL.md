# 04 — Combat Model (controls, height, attacks, starter kits)

**Status: proposed — under review.** This document supersedes the aiming/control assumptions in `02-ARCHITECTURE.md` §7, the `AttackDef` shape in §5, and the character kits in `03-GYM-SPEC.md` §2. Those were written against a misread of the source design (a cursor/cone aim model conflated with a separate energy-ability system that does not apply here). Once this is agreed, those sections get reconciled to match.

Everything numeric here is a **placeholder** to tune in the Inspector.

## 1. Control model

- **Input:** keyboard **and** controller both supported; **controller is the recommended** device. Keyboard is the current test input.
- **8-way gating (total, this stage):** player **movement and attack fire** both snap to the 8 compass directions (N/S/E/W + 4 diagonals), mapped to fixed angles (0/45/90/135/180/225/270/315°). Analog stick input is resolved to the nearest gate — the arcade-stick feel — switchable rapidly.
- **Facing = the movement-derived forward vector.** Characters initialize facing **North** and retain their last facing when idle. Both attacks fire straight along the current facing.
- **Enemies** move on the 8-gate too but **may fire off-gate**; **bosses are often unrestricted**. Treat this as design *sentiment*, not a hard law — we set rules and break them deliberately for interest.
- **Deferred (not this stage):** holding an attack to bring up **finer aim at the cost of movement**. Noted for later; nothing fine-aim now.

## 2. Height as a 2D scalar (not real 3D)

The game stays flat 2D pixel art. A projectile carries a single **`height` scalar** that drives three things at once:

1. **Its live collision channel** via thresholds — near-ground → **LOW**, mid → **BOTH**, peak → **HIGH**. A lob that rises and falls therefore passes through `BOTH → HIGH → BOTH → LOW` automatically.
2. **Sprite scale** (higher reads as bigger/closer to camera).
3. **An oval shadow** on the ground that scales **inversely** (higher projectile = smaller, fainter shadow).

**Height is driven over distance travelled, not just time** — so clearing an obstacle is a **spacing skill**: too close and the shot is still low when it reaches the wall (blocked); too far and it has descended past the wall's height (blocked) or overshot the target; at the right range it arcs over and lands on the target. This "find the distance" play is the intended depth, and the gym's low wall is the test rig for it.

Static targets keep **fixed** channels (a ground dummy is always `hurt_low`, a platform dummy always `hurt_high`, a low wall always `block_low`). Only **projectiles** gain a varying height. The collision-layer channel system from `02-ARCHITECTURE.md` §4 is unchanged — height just feeds it.

## 3. `AttackDef` v2 (proposed data model)

Attacks compose along a few orthogonal, data-driven axes (all Inspector-editable; no bespoke scripts per attack). Replaces `aim_type`/`cone_degrees`.

| Axis | Options | Notes |
|---|---|---|
| **Height profile** | `GROUND` · `LOB` · `LOB_BOUNCE` | GROUND = constant low. LOB = one rise/fall arc over distance. LOB_BOUNCE = arc that bounces on ground impacts, each smaller. |
| **Lateral motion** | `STRAIGHT` · `SINE` (amplitude, wavelength) | SINE = the wiggle that widens a ground shot's hit chance. |
| **Wall interaction** | `STOP` (default) · `REFLECT` | REFLECT bounces off walls at the angle of incidence (hit at 45° → leave at 135°); travels until range expires. |
| **On-hit / on-impact effect** | `NONE` · `SLOW_FIELD` · `AREA_SPILL` · `QUAKE` | Implemented as small reusable effect scenes the projectile spawns; see kits. |
| Core numbers | damage (half-hearts), cooldown, speed, range, projectile art | As today. Channel is static (GROUND shots) or derived-from-height (arcs). |

The **primary** attack is, by convention, a **forward LOW** shot; the **secondary** carries the character's variety (height, effect, or battlefield impact).

## 4. Starter kits

Player-facing handles (real names in parentheses). Each starter answers both high and low; small effect differences give each a role.

### Johnny Cool (Johnny) — the standard, fastest mover
- **Primary — TP Roll:** forward, LOW, `SINE` lateral wiggle. Art: `tp.png` roll + cosmetic `tp-trail.png` tail trailing behind. No standout effect — but the wiggle gives extra chances to clip ground enemies, and Johnny is the fastest character.
- **Secondary — TP Lob:** `STRAIGHT` `LOB` (high throw, no wiggle), `tp.png`, oval shadow. Clears low walls to strike ground targets beyond.

### Curly (Curt) — control/slow, tanky
- **Primary — Bleu Cheese Packet:** forward, LOW, `bleu-cheese.png`. On enemy hit → `SLOW_FIELD`: a small ground slow area (~shadow-sized, ~0.5–1 s), shown as a cream oval.
- **Secondary — Bleu Cheese Container Lob:** `LOB`, `bleu-cheese.png` container. On impact → `AREA_SPILL`: play the 9-frame `bleu-cheese-explosion.png`, then a **wider, longer-lasting** cream slow-oval that scales up then fades.
- **Role:** best against fast-moving enemies (he can slow them).

### Scum (Gary) — groups & corridors
- **Primary — Bowling Ball Roll:** forward, LOW, `bowling-ball.png` (15-frame roll anim), `REFLECT` — bounces off walls at the incidence angle; great down corridors and into clusters.
- **Secondary — Bowling Ball Lob-Bounce:** `LOB_BOUNCE` — one high lob, then two diminishing bounces, then it's destroyed. Each ground impact (the first especially) triggers `QUAKE`: a white oval flash on the ground dealing damage.
- **Role:** area denial / crowds / lanes.

### Stanley — deferred
WIP art (`stanley.png` is oversized for this resolution and needs a downscale). Kit TBD; not part of the first gym build.

## 5. Naming & art notes

- Handles: **Johnny Cool**, **Curly**, **Scum** (this supersedes the earlier "Johnny Weenie"). Real names Johnny / Curt / Gary.
- File spelling: the sheet is `kurt.png` but the character is **Curt / Curly** — data uses Curt; the art filename can stay or be renamed later.
- Game-ready art: `SCUMForce/public/assets/sprites/characters/{johnny,kurt,gary,stanley}.png` and `.../projectiles/{tp,tp-trail,bleu-cheese,bleu-cheese-explosion,bowling-ball}.png`. Raw/originals in `.../art_drop/_staging/`. Sheets are Gain-Ground-style, expected 8-directional.

## 6. What stays / what changes in code

**Unchanged:** the physics-layer channel system, structures, dummies, the spawner→hurtbox routing, the view stack, autoloads.
**Changes:** `player.gd` (8-gate move + facing); the input map (KB + controller, attacks on buttons, no mouse); `AttackDef` (the v2 model above); `projectile` (height scalar → mask + scale + shadow, motion patterns, wall/ground behavior, multi-part visual); new small **effect scenes** (slow field, area spill, quake); the character `.tres` + Gary added.

## 7. Explicitly deferred
Fine-aim mode · Stanley · boss behaviors · real balance numbers · escort/downed/HUD (that's the gym's Wave 2) · any 3D.
