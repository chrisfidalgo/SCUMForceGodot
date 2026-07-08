# Player Controller & Aiming

One scene plays every character. `scenes/characters/player.tscn` is a **`CharacterBody2D`** — a node built to be moved by script (`move_and_slide()`) while still colliding with solid geometry, so arena walls will stop it once P1b's walls exist. It's driven entirely by whichever `CharacterDef` resource is assigned to it: move speed, health, and both attacks come from data, not from a per-character script. Making a new playable character later means making a new `.tres` in `resources/characters/`, not writing a new controller.

## Nodes in `player.tscn`

| Node | Type | Job |
|---|---|---|
| `Player` (root) | `CharacterBody2D` | Movement, facing, aim, attack input. Script: `player.gd`. On physics layer `player_body`, collides with `world`. |
| `CollisionShape2D` | — | The body's physical footprint (a small circle). |
| `BodyVisual` | `Polygon2D` | Placeholder colored body — click it and edit **Color** in the Inspector, no script needed. |
| `FacingIndicator` | `Line2D` | A short line from the player toward the mouse cursor, updated every frame — this is the "which way am I aiming" readout. |
| `DebugFireFlash` | `Line2D` | Standalone-testing aid only: flashes along the resolved aim direction when an attack fires. Not part of gameplay. |

## Tunable knobs (Inspector, no script editing)

Select the `Player` node in `player.tscn` (or an instance of it) and look at the Inspector:

- **Character Def** — drag a different `resources/characters/*.tres` here to play a different character. Defaults to Johnny for standalone testing.
- **Muzzle Offset Px** — how far in front of the player attacks spawn from, along facing.
- **Debug > Show Debug Aim Feedback** — toggle the red flash line off if it's distracting.
- **Debug > Debug Fire Flash Seconds** — how long that flash line stays on screen.

Everything else — move speed, health, cooldowns, cone angles, damage, range — lives on the `CharacterDef`/`AttackDef` `.tres` files themselves (`resources/characters/`, `resources/attacks/`), per `docs/systems/00-godot-primer.md`.

## How facing and aiming work

**Facing** is simply the normalized direction from the player to the mouse cursor, recomputed every physics tick — the player always "looks at" the cursor.

Each attack has an `aim_type` on its `AttackDef`, and the controller resolves it to a final `aim_direction` before firing:

- **FIXED** (e.g. Rind Slam) — ignores the cursor entirely; direction doesn't matter because the attack is a self-centered pattern (a radial burst around the player).
- **FORWARD_VECTOR** (e.g. TP Roll) — fires straight along facing.
- **FREE_CONE** (e.g. Long Toss, Cheese Wheel) — aims toward the cursor, but clamped to within the attack's `cone_degrees` (an arc centered on facing). Because facing *is* the cursor direction in this controller, the clamp won't visibly clip anything today — it's built as a general, reusable function (`Player.resolve_aim_direction`) so a later change (e.g. turn-rate-limited facing, controller-stick aiming) doesn't require touching this code.

## Attacks, cooldowns, and the fire signal

`attack_primary` (left mouse) fires the character's `primary_attack`; `attack_secondary` (right mouse) fires `secondary_attack`. Each has its own independent cooldown timer taken from that attack's `cooldown_sec` — Johnny's fast 0.25s TP Roll and slow 1.2s Long Toss don't share a cooldown. Holding the button down keeps firing automatically once the cooldown clears.

This controller does **not** spawn projectiles — that's a separate packet's job. Instead, on every successful fire it emits a **signal** (a message a node broadcasts that any other node can listen for, without the sender needing to know who's listening):

```
signal attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2)
```

`origin` is the world-space muzzle point (player position + muzzle offset along facing); `aim_direction` is the resolved, normalized direction after aim-type handling. The projectile-spawner packet listens for this signal and does the actual spawning.

## Runtime character swap

`Player.set_character(def: CharacterDef)` swaps the active character at runtime (used by the debug tray's swap hotkey and the rescue flow later) and resets both attack cooldowns so the newly active character can fire immediately.

## How to test by hand

1. Open `scenes/characters/player.tscn` in the editor and press **F6** (runs just this scene, no arena needed — an empty background is expected).
2. **WASD** or arrow keys move the placeholder blue body.
3. Move the mouse — the yellow `FacingIndicator` line always points at the cursor.
4. Left-click / right-click to fire Johnny's TP Roll / Long Toss. A brief red debug line shows the resolved aim direction and range; watch it respect Long Toss's 120° cone limit as you swing the mouse around, and notice each attack respects its own cooldown (TP Roll fires much faster than Long Toss).
5. To test Curt instead, drag `resources/characters/curt.tres` onto the **Character Def** field in the Inspector and re-run.

## Assumptions & placeholders

- Body shape/size, colors, and the facing-indicator/debug-flash look are all placeholder pre-art values, freely editable in the Inspector.
- Cooldowns are tracked per attack **slot** (primary/secondary) rather than per `AttackDef` instance — correct for this game since each character has exactly one fixed attack per slot, and simpler than tracking per-resource state.
- `set_character` resets cooldowns to zero on swap (a freshly active character can act immediately) rather than preserving a partial cooldown from before the swap.
- No projectile, hurtbox, health, or downed/mini logic lives here by design — this packet stops at emitting `attack_fired`.
