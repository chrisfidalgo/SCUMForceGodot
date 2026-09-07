# Live tuning panel

**Scene:** `scenes/ui/tuning_panel.tscn` (+ `.gd`) · **Globals:** `scenes/combat/combat_tuning.gd`
**Where it's wired:** instanced as a child of `scenes/combat/gym.tscn`

## What it's for

Balance work normally goes: stop the game, change a number, start the game, try
to remember what the old feel was. This panel removes that loop. Press **`` ` ``**
(the backtick/tilde key, left of `1`) while playing and a slider panel appears
over the game. Drag a slider and the change applies **immediately**, mid-flight,
without leaving play mode. Press `` ` `` again to hide it.

When you've dialed in something good, click **"Log values to console"**. It prints
a snapshot of every current number to Godot's Output panel so you can copy them
back into the `.tres` files by hand.

**Changes made here are not saved.** They live only in the running game and are
gone when you stop it. That is deliberate — you experiment freely, and only the
numbers you consciously copy back become real. The log button is how they become
real.

## What is in it

Top to bottom: the **active character's own numbers**, then that character's
**primary** and **secondary** attacks, then the **global** projectile/height
knobs, then a section for every enemy on the field.

The character block is first on purpose. `move speed` is the entire
Johnny-vs-Curly contrast — the fast/fragile versus slow/tanky bet this whole gym
exists to test — so it should not be buried in a `.tres` file you have to stop
the game to open. `max half-hearts` is there too, and it writes through to the
live health pool as well as the resource, so the HUD updates as you drag it.

## Two kinds of number, two homes

This trips people up, so it's worth being explicit.

**Per-character numbers** — move speed, max half-hearts — live on the
`CharacterDef` resource, alongside `placeholder_color` (Johnny is purple, Curly
green, so a swap is visible at a glance and a downed mini is identifiable).

**Per-attack numbers** — speed, range, damage, cooldown, lob peak, sine wobble —
live on the `AttackDef` resource (`.tres`) for that attack. Each character's
attacks are separate files, so changing Johnny's TP Roll cannot affect Curt.

**Cross-cutting numbers** — the ground shadow's size and opacity, how much a
projectile's sprite grows with height, the trail's gap and animation speed, and
the **height thresholds that decide whether a projectile counts as LOW, BOTH, or
HIGH** — live on `CombatTuning` as `static var`s.

Why the split: a `.tres` resource is loaded once and shared, which is perfect for
"Johnny's TP Roll deals 1 damage." But the height thresholds are consulted by
every projectile on every physics frame, and they aren't a property *of* any one
attack. `static var` means there is exactly one copy that everything reads live,
so moving the "both↔high" slider changes how every projectile in the air behaves
on the very next frame.

That last group is the most interesting thing in the panel. **`ground<->both` and
`both<->high` are the dials that decide how easily a lob clears a low wall.**
Widening the HIGH band makes lobs forgiving; narrowing it makes wall-clearing a
precise spacing skill. That is a core-feel decision, not a cosmetic one.

## Putting your own knobs in it

The panel is **not player-only**. Anything can add a section. Put the node in the
`tunable` group (Godot's "group" = a named tag you can add to any node, in the
editor's Node → Groups tab or in code with `add_to_group("tunable")`), then
implement whichever of these three methods you need:

```gdscript
func get_tuning_label() -> String:
    return "SEEKER"                      # your section header

func get_tuning_attacks() -> Array:      # optional
    return [attack_def]                  # gets the full attack slider set

func get_tuning_spec() -> Array:         # optional
    return [                             # any plain number on this node
        {"property": "move_speed",       "min": 10.0, "max": 200.0, "step": 5.0},
        {"property": "fire_cooldown_sec", "min": 0.2, "max": 5.0,  "step": 0.1},
    ]
```

That's the whole contract. Your section appears automatically, and your numbers
appear in the console snapshot too.

**Why a group instead of the panel knowing about enemies directly:** packets are
drawn so no two agents edit the same file (`01-AGENT-BRIEFING.md`). If enemies
had to be added to `tuning_panel.gd` by name, every packet that adds a tunable
thing would edit one shared script and collide. With the group contract, a packet
touches only its own files.

## How to test it by hand

1. Open `scenes/combat/gym.tscn`, press **F6**.
2. Press `` ` ``. The panel appears top-left.
3. Fire the secondary (K) at the dummy behind the low wall. Note whether it clears.
4. Drag **`both<->high`** down. Fire again — the lob now counts as HIGH earlier
   and clears more easily. Drag it up and the same shot gets blocked.
5. Drag **`shadow alpha`** and **`tail gap`** while shots are in the air; the
   change is visible on projectiles already flying.
6. Click **Log values to console** and check Godot's Output panel.

If the panel doesn't appear, check that `gym.tscn` actually has a `TuningPanel`
*node* — importing the scene as a resource without instancing a node is silently
valid in Godot and produces exactly this symptom.

## Not in scope

No saving back to `.tres` from the panel (copy via the log button — deliberate,
so experiments can't silently become canon). No preset save/load. No per-slider
undo. None of this ships in a real build.
