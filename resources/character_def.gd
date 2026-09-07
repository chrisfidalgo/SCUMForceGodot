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
