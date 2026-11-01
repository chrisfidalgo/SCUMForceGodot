class_name CharacterDef
extends Resource
## CharacterDef — one playable character's tunable data (a custom Resource).
##
## Saved as a `.tres`; every @export below is an Inspector row. One generic
## player controller reads a CharacterDef, so characters differ by DATA, not by
## bespoke scripts. New character = new .tres file.
##
## Health is counted in half-hearts (2 half-hearts = 1 heart on the HUD).

@export var display_name: String = ""
@export var move_speed: float = 120.0            ## px/s
@export var max_half_hearts: int = 4             ## e.g. 4 = two hearts
@export var primary_attack: AttackDef            ## Left mouse.
@export var secondary_attack: AttackDef          ## Right mouse.
@export_group("Art (placeholder until real sprites)")
## Body colour used until real sprites exist. It is per-character rather than
## baked into player.tscn so that swapping characters visibly changes who you
## are — during the core-feel playtest you have to be able to tell at a glance
## whether you are driving the fast one or the tanky one. The matching mini uses
## this too, so a downed teammate is identifiable on the field.
@export var placeholder_color: Color = Color(0.3, 0.55, 0.9)
@export var sprite: Texture2D                    ## In-arena body.
@export var portrait: Texture2D                  ## HUD / select screen.

@export_group("Walk sheet (real art)")
## Walk-cycle sprite sheet: a grid of frames, one ROW per facing direction, one
## COLUMN per walk frame. Leave empty to fall back to the coloured placeholder.
@export var walk_sheet: Texture2D
## Size of ONE frame in sheet pixels (e.g. 50x50 for a 150x400 sheet of 3x8).
@export var walk_frame_size: Vector2i = Vector2i(50, 50)
## Frames per row (walk-cycle length).
@export var walk_columns: int = 3
## Which column to hold while standing still (0 = first frame).
@export var walk_idle_column: int = 1
## Walk-cycle speed in frames per second.
@export var walk_fps: float = 8.0
## Which sheet ROW shows each facing. The ORDER OF THIS LIST is fixed:
##   index 0 = N (up/back), 1 = NE, 2 = E, 3 = SE, 4 = S (down/front), 5 = SW, 6 = W, 7 = NW
## and each VALUE is the row number in the sheet (0 = top row). If a character
## turns the wrong way, swap the row numbers here — no code involved.
@export var walk_rows_by_direction: Array[int] = [0, 2, 3, 7, 1, 4, 6, 5]
## Multiplier on the sheet's pixel size (0.5 = half size on screen).
@export var sprite_scale: float = 0.5
## Shift of the sprite from the body's position, in screen pixels, so the baked
## shadow sits under the feet. Negative Y moves the art up.
@export var sprite_offset: Vector2 = Vector2(0, -6)
