# Touch controls (phones and tablets)

An on-screen stick and three buttons that appear on touch devices. Nothing in
the game was changed to support them: the overlay presses the same input
actions the keyboard does.

Files: `scenes/ui/touch_controls.tscn` / `.gd`, registered as the
`TouchControls` autoload in `project.godot`. Being an autoload, it floats over
every scene (launcher, gym, run, picker, between-level cards) and keeps working
while the game is paused.

## What the player sees

| Control | Where | What it does |
|---|---|---|
| Stick | Touch anywhere in the left ~45% of the screen (below the top strip) | A floating stick appears where the thumb lands. Movement snaps to 8 directions, same as the keyboard. |
| **A** | Bottom-right | Primary attack (`attack_primary`) |
| **B** | Up-left of A | Secondary attack (`attack_secondary`) |
| **OK** | Top-right | Continue / confirm (`ui_accept`): between-level cards, menus |

The stick also presses `ui_up/down/left/right`, so menus respond to it.
Multi-touch works: hold the stick and tap A or B at the same time.

## When it shows

- Automatically when the browser reports a touchscreen.
- Hidden on normal desktops, so keyboard players see nothing different.
- On a touch laptop it hides itself when a key is pressed and comes back on the
  next screen touch (`hide_on_keyboard`).
- To test on desktop: open `scenes/ui/touch_controls.tscn`, tick **Force
  Visible**, and run the scene you want. (Mouse clicks do not drive the stick;
  only real or emulated touches do. Use Project Settings > Input Devices >
  Pointing > Emulate Touch From Mouse to test with the mouse.)
- In a portrait phone a "Rotate your phone to landscape" message appears.

## Tapping menus still works

Godot turns touches into mouse clicks, so the launcher buttons and the picker
work as usual. The stick will not start a drag on top of a button or slider,
and the A/B/OK circles swallow the click underneath them (so tapping A never
presses a button hiding behind it).

## Tuning (Inspector, on `touch_controls.tscn`)

All sizes are in the 640x360 game pixels.

- **Overlay:** Force Visible, Hide On Keyboard, Opacity.
- **Stick:** zone width, top margin, radius (how far to drag for full tilt),
  dead zone (fraction of radius that counts as centred), knob size, idle ring.
- **Buttons:** margin, radius of each button, gap, secondary lift, label size,
  colours.

## Known limits

- Placeholder art: flat circles with letters.
- Interact, inventory and pause have no touch buttons (not needed by the
  current build).
- The debug tray (F1-F6) and the tuning panel are keyboard-only.
- Verified with injected touch events only; first real-phone pass still owed.
