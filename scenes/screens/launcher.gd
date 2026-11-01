extends Control
## launcher.gd — the temporary first screen: pick the fixed run or the gym.
##
## Stands in for the real Splash screen (Phase 2, P2a) so that F5 and the web
## build land somewhere playable. Both targets are self-contained scenes with
## their own camera, so this swaps the whole scene rather than going through
## GameFlow's screen layer. P2a replaces this file outright.

@export_file("*.tscn") var run_scene: String = "res://scenes/run/fixed_run.tscn"
@export_file("*.tscn") var gym_scene: String = "res://scenes/combat/gym.tscn"

@onready var _run_button: Button = %RunButton
@onready var _gym_button: Button = %GymButton


func _ready() -> void:
	_run_button.pressed.connect(_go.bind(run_scene))
	_gym_button.pressed.connect(_go.bind(gym_scene))
	_run_button.grab_focus()


func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)
