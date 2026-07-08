extends Node
## main.gd — the permanent root scene (never freed).
##
## main.tscn is the game's root: it holds the three layers (ScreenRoot,
## ModalLayer, TooltipLayer) and boots the flow. On startup it hands those
## layers to the GameFlow autoload, then routes to the first screen. From here
## on, only GameFlow changes what's on screen.

## Phase 0 boots to a throwaway placeholder. Phase 2 (P2a) replaces this with
## the real Splash screen (New Game / Continue / Settings).
const FIRST_SCREEN: PackedScene = preload("res://scenes/screens/placeholder.tscn")

@onready var screen_root: Node = $ScreenRoot
@onready var modal_layer: CanvasLayer = $ModalLayer
@onready var tooltip_layer: CanvasLayer = $TooltipLayer

func _ready() -> void:
	GameFlow.register_layers(screen_root, modal_layer, tooltip_layer)
	GameFlow.goto_screen(FIRST_SCREEN)
