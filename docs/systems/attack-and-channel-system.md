# Attack & Channel System

The single most important mechanic in the gym: attacks belong to a **channel** (LOW / HIGH / BOTH), targets and structures live on matching physics layers, and Godot's own collision system — not a script `if` statement — decides who can hit whom. This is what makes "the right character for the situation" a physical rule instead of a suggestion.

## The idea in one picture

| | GROUND target (`hurt_low`) | ELEVATED target (`hurt_high`) | TALL target (`hurt_low`+`hurt_high`) |
|---|---|---|---|
| **LOW** attack | hits | **misses** | hits |
| **HIGH** attack | **misses** | hits | hits |
| **BOTH** attack | hits | hits | hits |

| | LOW WALL (`block_low`) | TALL WALL (`block_low`+`block_high`) |
|---|---|---|
| **LOW** attack | stopped | stopped |
| **HIGH** attack | **passes over** | stopped |
| **BOTH** attack | stopped (by whichever it hits first) | stopped |

TP Roll (LOW) shreds anyone standing in the open but can't touch someone on a platform. Long Toss (HIGH) sails clean over a low crate wall and reaches that platform, but whiffs entirely on ground-level targets. Cheese Wheel (BOTH) reaches everyone but gets stopped by the first wall of either kind it meets. Rind Slam is LOW and centered on the caster — pure positioning, no aim at all.

## How it's actually built (for the curious)

Two Godot ideas make this work:

- **`Area2D`** is a node that reports "something overlapped me" without physically pushing or blocking anything — perfect for a projectile, which should pass through everything it's not meant to touch and stop cleanly on the first thing it is.
- Every `Area2D` has a **`collision_layer`** (what it *is*, for others to detect) and a **`collision_mask`** (what it can *detect*). A hurtbox on `hurt_low` is detectable by anything whose mask includes `hurt_low`; it's invisible to everything else. This is a **bitmask** — each of the eight named physics layers is one bit, and a mask is just several bits combined, so "detect `hurt_low` and `block_low`" is one number a computer can check instantly.

Every projectile's `collision_mask` is computed from its attack's `channel` by one function — `ChannelMasks.mask_for_channel()` in `scenes/combat/channel_masks.gd`:

- **LOW** → `hurt_low` + `block_low`
- **HIGH** → `hurt_high` + `block_high` (deliberately *not* `block_low` — that's the whole "lobs over low walls" trick)
- **BOTH** → all four

That's it — that one mapping, applied to a projectile's `collision_mask`, is the entire channel system. A `TestHurtbox` (the placeholder stand-in used in the test scene) or a real dummy just needs to sit on the right `hurt_*` layer and expose a `receive_hit(damage_half_hearts)` function; a blocker just needs to sit on the right `block_*` layer with no such function. Neither needs to know the channel system exists.

## Where the knobs are

Every number above — damage, cooldown, projectile speed, range, cone angle, channel, aim type — lives in the attack's `.tres` file in `resources/attacks/` (`tp_roll.tres`, `long_toss.tres`, `cheese_wheel.tres`, `rind_slam.tres`). Open one in the Inspector and every field is editable there; nothing is hardcoded in a script. Changing a `channel` dropdown from LOW to HIGH in the Inspector immediately changes which walls and targets that attack can reach — no code change needed.

## How to fire an attack from code

One function spawns everything, reading entirely from the `AttackDef` passed in:

```
AttackSpawner.spawn_attack(attack: AttackDef, origin: Vector2, aim_direction: Vector2, source: Node) -> void
```

- If the attack travels (TP Roll, Long Toss, Cheese Wheel), it spawns a `Projectile` (`scenes/combat/projectile.tscn`) moving along `aim_direction` at `attack.projectile_speed`, expiring after `attack.range_px`.
- If the attack is `FIXED` (Rind Slam), it spawns a short-lived `AttackBurst` — a circle of radius `attack.range_px` centered on `origin` that hits everything on the attack's channel once, then disappears.
- `source` is optional and lets the caller (e.g. the player firing the shot) exclude its own hurtbox from being hit by its own attack.

**Placeholder note for the integration pass:** `AttackDef.projectile_scene` is empty on all four P0 `.tres` files, so `AttackSpawner` falls back to an `@export`ed `default_projectile_scene` (set to `projectile.tscn` by default). Nothing currently needs a *different* projectile visual per attack — the channel, not the sprite, is what matters for behavior — so leaving `projectile_scene` empty and letting every attack share one generic projectile is a reasonable permanent choice. If a later packet wants a distinct look per attack (e.g. a spinning TP wad vs. a lobbed cheese wheel), populate `projectile_scene` per `.tres` and the spawner will pick it up automatically with no code change.

## How to test it by hand

Open `scenes/combat/projectile_test.tscn` and press **F6**. It's a standalone proof scene — not part of the shipped game — with placeholder hurtboxes and blockers (no real player or dummies needed, since those belong to other work packets):

- Five lanes run bottom-to-top. The first three have an unobstructed GROUND, ELEVATED, or TALL dummy — press **1/2/3** (or the matching button) to fire TP Roll / Long Toss / Cheese Wheel down all five lanes at once and watch each dummy's "hits" counter to confirm the channel × elevation table above.
- Lanes four and five put a LOW WALL or TALL WALL partway up the lane with a TALL dummy behind it — the same keypress shows which attacks get stopped and which pass through.
- A cluster to the right has two targets near a single point — press **4** to fire Rind Slam and confirm it hits the nearby GROUND target but not the ELEVATED one, even though both are within its blast radius.

There's also a headless, automated version of the same proof: `scenes/combat/attack_channel_check.gd`, runnable via `godot --headless --path . --script res://scenes/combat/attack_channel_check.gd`. It asserts the mask bitfields directly and then fires all four real attacks at synthetic hurtboxes/blockers, printing PASS/FAIL for every case in the tables above.
