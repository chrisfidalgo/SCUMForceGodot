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
@export var sprite: Texture2D                    ## In-arena body.
@export var portrait: Texture2D                  ## HUD / select screen.
