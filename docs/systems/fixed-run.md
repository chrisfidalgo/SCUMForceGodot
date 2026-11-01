# The fixed run

A short, fixed chain of levels played in order: the first complete loop of the
game. It exists to prove the structure (pick a character, fight, exit, carry
health forward, lose people to the clock) before the Phase 2 map screen, shop and
saving are built. It is deliberately dumb: no choices between levels, no save.

**Play it:** open `scenes/run/fixed_run.tscn` and press **F6**. Press **Enter**
on any card to continue (or restart after the run ends).

Code: `scenes/run/fixed_run.gd` (class `FixedRun`). You never need to edit it -
everything below is set in the Inspector.

## What happens

1. The run starts: `RunState` is wiped and filled with the starting roster at full
   health.
2. Level 1 appears. The game pauses on **"Who goes in?"** - pick a character.
3. When that character exits or goes down, you pick the next (if only one is left
   they go in automatically). See `encounters.md` for the stage rules.
4. When the level resolves, the run writes the results into `RunState`, throws the
   level away, and shows a **card**: how it ended, everyone's health, the next
   level's name, "Enter to continue".
5. After the last level, or if the run is lost, a **run-end card** shows
   RUN COMPLETE or RUN OVER. Enter restarts from level 1.

## How a level can end

| Outcome | When | What it means for the run |
|---|---|---|
| **CLEARED** | every enemy is dead | Whoever is still standing counts as survived. Run continues. |
| **ESCAPED** | everyone has been used (exited or downed) and at least one exited | Run continues. |
| **LOST** | everyone went down, nobody exited | Run over. |
| **TIME'S OUT** | the level timer hit 0 | Run continues, but **random roster members are removed for good** (card names them). |

The boss room only ends by CLEARED or LOST (it has no exit).

## What carries to the next level

| What happened to the character | Health next level |
|---|---|
| Exited the level (survived) | The health they had. |
| Went down, then was rescued and carried out the exit ("banked") | `banked_return_half_hearts` |
| Went down and was left on the field | `downed_return_half_hearts` (they are still in the run) |
| Never deployed, or still on the field at Time's Out | Unchanged. |
| Removed by Time's Out | Gone for the rest of the run (shown as LOST). |

Nobody dies permanently from being downed; that is the easiest tier of the
death-permanence rule. Only Time's Out removes people.

## The Inspector knobs (select the `FixedRun` node)

| Export | What it does |
|---|---|
| `levels` | The levels, **in play order**. Drag scenes from `scenes/levels/`. |
| `starting_roster` | Who is in the run, at full health. Drag `CharacterDef` files from `resources/characters/`. |
| `banked_return_half_hearts` | Health a rescued-and-banked character returns with (half-hearts; default 2). Placeholder - tune by feel. |
| `downed_return_half_hearts` | Health an unrescued character returns with (default 1). Placeholder. |
| `time_out_removals` | How many random active characters a Time's Out removes (default 1). |
| `Card look` group | Font size, size, colours of the between-level / run-end card. |

Health is measured in **half-hearts** everywhere (Johnny has 4, Curt 8).

## Add a level to the run

1. Make the level scene (next section).
2. Select `FixedRun` in `fixed_run.tscn`, find `levels` in the Inspector, click
   **Add Element**, and drag your level scene into the new slot.
3. F6 to play. The card before it shows its `display_name`.

## Reorder or remove levels

Drag the entries in the `levels` array to reorder them, or delete an element. The
**last** entry is the finale: resolving it ends the run (RUN COMPLETE).

## Make a new level

A level is an **inherited scene** of `scenes/combat/encounter_base.tscn` - the base
already has the floor, walls, camera, player, HUD, picker and exit.

1. In the editor: **Scene -> New Inherited Scene**, choose
   `scenes/combat/encounter_base.tscn`, then **Save As** into `scenes/levels/`.
2. Select the root node and set, in the Inspector:
   - `display_name` - shown on the HUD and the cards.
   - `time_limit_sec` - 0 means no timer; otherwise Time's Out when it hits 0.
   - `is_boss` - tick for a clear-only room (the exit is hidden and disabled).
   - `default_roster` - used only when you run the level alone with F6.
3. Add **enemies**: drag `scenes/enemies/enemy.tscn` in (put them under an
   `Enemies` Node2D to keep the tree tidy), then set the node's `Def` to a file
   from `resources/enemies/`. `Elevation` and `Facing Degrees` (for fixed-aim
   turrets: 0 = right, 90 = down) are per placement.
4. Add **cover**: drag from `scenes/structures/` (`low_wall`, `tall_wall`,
   `platform`). A low wall stops low shots; a tall wall stops everything.
5. **Move the exit** (`ExitZone`) and `PlayerSpawn` if you want. The canvas is
   640 x 360; the player starts at the bottom by convention.
6. Press F6 on the level to try it by itself.

**Every combat level must have at least one enemy** - otherwise the console
shows an error naming the scene.

### Patrolling enemies

A patroller needs a route. Add a plain `Node2D` (e.g. `Routes/RouteA`) with
`Marker2D` children - the markers, in order, are the waypoints. Optionally attach
`scenes/enemies/patrol_route.gd` to the Node2D to see the route drawn in the
editor. Then on the enemy, set **Patrol Route** by clicking the field and picking
the route node. If you forget, the enemy stands still and the console warns.

> Gotcha for hand-editing `.tscn` files: a node reference such as `patrol_route`
> only binds if the node's header carries `node_paths=PackedStringArray("patrol_route")`.
> The editor does this for you; it matters only when writing scene text by hand.

## Things to know

- With two characters in the roster you only see the picker at the very start of
  each level: after the first character leaves, the second goes in automatically.
- The run owns `RunState`; levels only read it. A level never changes the
  roster itself.
- Not built yet (Phase 2): map screen, shop, saving, character-select screen.
