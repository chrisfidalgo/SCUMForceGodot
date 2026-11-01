# Character art (walk sheets, portraits, character select)

## What a character needs
All art lives on the character's `.tres` (`resources/characters/*.tres`), under
the **Art** groups in the Inspector. Nothing is in code.

| Field | Meaning |
|---|---|
| `portrait` | Picture for the HUD (small) and character select (large). |
| `walk_sheet` | The walk-cycle sprite sheet. Empty = the coloured placeholder diamond is used. |
| `walk_frame_size` | One frame in sheet pixels (50 x 50). |
| `walk_columns` | Frames per row (3). |
| `walk_idle_column` | Which column is held when standing still (1 = middle frame). |
| `walk_fps` | Walk-cycle speed. |
| `walk_rows_by_direction` | Which sheet row shows each facing (see below). |
| `sprite_scale` | On-screen size multiplier (0.5 = half the sheet pixels). |
| `sprite_offset` | Nudge in screen pixels so the baked shadow sits under the feet. Negative Y = up. |

## Adding a new character's sheet
1. Drop the PNG in `assets/sprites/characters/<name>/` (pixel art; the project
   already filters textures nearest, so it stays crisp).
2. Sheet layout: **one row per facing, one column per walk frame**, shadow baked
   into each frame.
3. Open the character's `.tres`, drag the PNG onto `walk_sheet` and a picture onto
   `portrait`, set frame size / columns if different from 50x50 / 3.
4. Fill `walk_rows_by_direction` (next section), then tune scale/offset/fps.

## Fixing the direction rows
`walk_rows_by_direction` has exactly 8 entries, in this fixed order:

`[N, NE, E, SE, S, SW, W, NW]`

Each value is the **row number in the sheet, counting from 0 at the top**. If
the character looks the wrong way when walking, find which row *should* be used
and type that number into the matching slot. Example: if Curt faces left when
you walk right, swap the E and W entries.

Current mappings (checked by eye against the sheets):
- Johnny: `[0, 2, 3, 7, 1, 4, 6, 5]`
- Curt: `[0, 2, 6, 7, 1, 4, 3, 5]` (his sheet has E and W rows the opposite way round to Johnny's)

## Other knobs
- Player: `show_facing_indicator_with_sheet` (Inspector on the Player) turns the
  yellow aim line back on over the sprite. Off by default when a sheet exists.
- Hit feedback: the sprite flashes `invuln_flash_color` during i-frames.
- A character with no `walk_sheet` still works: the old coloured polygon and
  facing line are used.

## Character select (`deploy_picker`)
Shows one character at a time: portrait, name, hearts (half-heart pips), a
`1 / 2` counter, an up arrow above and down arrow below.
- Keyboard: W/S or Up/Down cycle (wraps), Enter or J deploys; number keys jump.
- Touch/mouse: tap the arrows to cycle, tap the portrait to deploy.
- Inspector knobs on `DeployPicker`: `portrait_size_px`, `arrow_size_px` (keep
  big for thumbs), colours, fonts, `hint_text`, and `confirm_arm_delay_sec`
  (ignores confirm presses just after opening, so the key that closed the
  previous card cannot also pick someone).
- No portrait on a character = a square of their `placeholder_color`.
