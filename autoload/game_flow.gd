extends Node
## GameFlow — the one place screens and modals change.
##
## Autoload (a script Godot loads once at startup and makes reachable from
## anywhere by its name, `GameFlow`). It owns the three layers defined in
## main.tscn: the active full-screen "screen", the modal stack above it, and
## the tooltip layer on top. Nothing else in the game swaps screens — call
## GameFlow.goto_screen(...) / push_modal(...) / pop_modal() instead.
##
## main.tscn registers its layers with GameFlow on startup via register_layers().

var screen_root: Node          ## Holds exactly one active screen at a time.
var modal_layer: CanvasLayer   ## Modals stack here, above the screen.
var tooltip_layer: CanvasLayer ## Singleton tooltip layer, topmost.

var _current_screen: Node = null
var _modal_stack: Array[Node] = []

## Called once by main.gd so GameFlow knows where to put screens and modals.
## Keeps GameFlow decoupled from main.tscn's exact node paths.
func register_layers(screens: Node, modals: CanvasLayer, tooltips: CanvasLayer) -> void:
	screen_root = screens
	modal_layer = modals
	tooltip_layer = tooltips

## Replace the active screen. Frees the old one, instances `scene` under
## ScreenRoot. `scene` is a PackedScene (a scene saved as a reusable asset).
func goto_screen(scene: PackedScene) -> void:
	if screen_root == null:
		push_error("GameFlow.goto_screen called before register_layers")
		return
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null
	if scene == null:
		return
	_current_screen = scene.instantiate()
	screen_root.add_child(_current_screen)

## Push a modal above the current screen (Shop, Event, Inventory later).
## Returns the instanced modal node so the caller can await/connect to it.
func push_modal(scene: PackedScene) -> Node:
	if modal_layer == null or scene == null:
		return null
	var modal := scene.instantiate()
	modal_layer.add_child(modal)
	_modal_stack.push_back(modal)
	return modal

## Close the top-most modal, if any.
func pop_modal() -> void:
	if _modal_stack.is_empty():
		return
	var modal: Node = _modal_stack.pop_back()
	if is_instance_valid(modal):
		modal.queue_free()

func modal_count() -> int:
	return _modal_stack.size()
