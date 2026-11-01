# Encounters

An **encounter** is one combat stage: an arena, some enemies, an exit, and the
rules for how it ends. Every level in the game is an encounter. The gym is a
special "sandbox" encounter that never ends, so you can test freely.

The code is `scenes/combat/encounter.gd` (class `Encounter`). You never edit it
to build a level - a level is a scene plus some numbers in the Inspector.

## How a stage plays

1. **Pick a character.** The game pauses and shows a menu: press the number key
   or click a button. Each button shows that character's health in half-hearts
   (HP 3 / 4). If only one character is left, they go in automatically.
2. The chosen character appears at the **PlayerSpawn** marker with the health
   they were carrying in.
3. They fight. From here a character can end in one of three ways:
   - **Reach the exit** - they *survived*. Any minis they were escorting are
     *banked*. That character is used up for this stage, and the menu appears
     again for the next one.
   - **Go down** - they leave a rescuable mini on the field and are used up.
     The menu appears for the next one.
   - Time or enemies run out (below).
4. Between picks nobody is on the field: the player is hidden, cannot move and
   cannot be hit.

## How a stage ends

The encounter announces its result exactly once, then freezes so nothing can
change afterwards.

| Result | When |
|---|---|
| **CLEARED** | Every enemy is dead. The character on the field counts as survived. Characters not yet picked count as neither survived nor downed. |
| **ESCAPED** | Nobody is left to pick, and at least one character reached the exit. |
| **LOST** | Nobody is left to pick, and nobody reached the exit. The run is over. |
| **TIMED_OUT** | The timer hit 0. Characters who already exited count as survived; the one on the field and anyone unpicked count as neither. |

The encounter only **reports**. It reads the run's roster (who is available, at
what health) but never changes it - the run harness does that. Punishments such
as "Time's Out removes one random character" are the harness's job.

### The report

Sent with the result. Characters are identified by the file path of their
`.tres` (for example `res://resources/characters/johnny.tres`).

- `survived` - character path to half-hearts left
- `banked` - paths of minis that were carried out through the exit
- `downed` - paths of characters who went down and were not carried out

## Making a new level

1. In the editor: **Scene > New Inherited Scene**, and choose
   `scenes/combat/encounter_base.tscn`. Save it (for example in `scenes/levels/`).
   You get the floor, walls, camera, player, spawner, exit, HUD and character
   menu already wired up.
2. Drag walls, platforms, and enemies (`scenes/enemies/enemy.tscn`) into the
   scene. Give each enemy a `def` (an enemy `.tres`). Move **PlayerSpawn** and
   **ExitZone** where you want them.
3. Select the root node and set the exports below.
4. Press **F6** to play it alone. With no run in progress it uses the
   `default_roster` characters at full health.

**Every combat level must contain at least one enemy.** If it has none, the
console shows an error naming the scene.

## The exports (root node, Inspector)

| Export | What it does |
|---|---|
| `display_name` | Level name shown at the top of the HUD. Blank = the node name. |
| `is_boss` | Clear-only room: the exit is hidden and switched off. Only CLEARED, LOST or TIMED_OUT can happen. |
| `sandbox` | Test mode (the gym): never ends, characters are never used up, the timer is ignored, the first roster member deploys automatically. |
| `time_limit_sec` | Countdown in seconds, shown on the HUD (turns red under 10). 0 = no timer. At 0 the screen says TIME'S OUT and the stage ends. The clock only runs while the game is unpaused. |
| `escort_penalty_multiplier` | Speed multiplier while escorting 2 or more minis (0.75 = 25% slower). One mini is free. |
| `default_roster` | Characters available when no run is in progress. The base scene starts with Johnny and Curt. |
| `edge_spawn_margin_px` | How far in from the screen edge debug-spawned enemies land when no position is given. |

## The gym

`scenes/combat/gym.tscn` is an encounter with `sandbox = true`. The F-key tray
still works: F4 forces the active character down, F5 swaps through
`default_roster`, F6 resets the field. It also has a **PatrolRoute** node with
four markers - any enemy given that route will walk it, in order.

## Good to know

- Whenever someone is choosing a character the whole game is paused. This is on
  purpose: choosing is never under fire.
- Enemies that are mid-death when the last one falls are not counted twice.
- Enemies spawned by script during play are counted too.

## The spawn pad and the deploy grace

`PlayerSpawn` carries a **SpawnPad**: a ring with a "START" label that pulses
while you are choosing a character, so you can see where you will land (and
what is standing near it) before you commit. It also draws in the editor. Its
size, colour, pulse speed and label are exports on the `SpawnPad` node.

While nobody is deployed, enemies have **no target** — they don't wake, chase or
aim at the empty spawn point (`Player.on_field` is false).

After each deploy there is a short **grace** (`deploy_grace_sec` on the
encounter's root, default 1 s): the character can move but enemies ignore them
and they can't be hurt, and the pad stays lit. Set it to 0 for no grace. The gym
uses 0 so its debug invincibility toggle isn't overridden.
