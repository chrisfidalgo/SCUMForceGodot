extends CanvasLayer
## debug_tray.gd — the gym's F-key control panel (03-GYM-SPEC.md §5).
##
## A CanvasLayer draws in screen space above the world, so this sits over the
## arena regardless of the camera. Everything here is a thin wrapper: the tray
## never implements a behaviour, it only calls a `debug_*` method on the gym or
## flips the channel overlay. That keeps the gym's rules in one place and lets
## this whole scene drop into a future encounter unchanged.
##
## Every action is available BOTH as a hotkey and as an on-screen button.
##
## NOTE ON KEY ALLOCATION: the input map is frozen after Phase 0
## (01-AGENT-BRIEFING.md), so only six debug actions exist (`debug_1`..`debug_6`
## on F1..F6). Three archetypes plus down/swap/reset already fills all six, so
## the channel overlay and invincibility are button-only. If they earn a hotkey
## during playtesting, that is a request to the orchestrator to unfreeze one
## input, not something to patch in here.

const ACTIONS := [
	{"action": "debug_1", "key": "F1", "label": "Spawn Wanderer"},
	{"action": "debug_2", "key": "F2", "label": "Spawn Turret"},
	{"action": "debug_3", "key": "F3", "label": "Spawn Seeker"},
	{"action": "debug_4", "key": "F4", "label": "Force down"},
	{"action": "debug_5", "key": "F5", "label": "Swap character"},
	{"action": "debug_6", "key": "F6", "label": "Reset gym"},
]

var _gym: Node = null
var _overlay: Node2D = null
var _status: Label = null


func _ready() -> void:
	_gym = get_parent()
	# See combat_hud.gd: the parent gym is not ready yet when a child readies.
	if not _gym.is_node_ready():
		await _gym.ready
	_overlay = _gym.get_node_or_null("ChannelOverlay")
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	for entry in ACTIONS:
		if event.is_action_pressed(entry["action"]):
			_run(entry["action"])
			get_viewport().set_input_as_handled()
			return


func _run(action: String) -> void:
	match action:
		"debug_1": _gym.spawn_enemy(Enemy.Archetype.WANDERER)
		"debug_2": _gym.spawn_enemy(Enemy.Archetype.TURRET)
		"debug_3": _gym.spawn_enemy(Enemy.Archetype.SEEKER)
		"debug_4": _gym.debug_force_down()
		"debug_5": _gym.debug_swap_character()
		"debug_6": _gym.debug_reset()
	_refresh_status()


func _toggle_overlay() -> void:
	if _overlay != null:
		_overlay.visible = not _overlay.visible
	_refresh_status()


func _toggle_invincible() -> void:
	_gym.debug_toggle_invincible()
	_refresh_status()


func _build_ui() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(6, 360 - 118)
	panel.size = Vector2(132, 112)
	add_child(panel)

	var rows := VBoxContainer.new()
	rows.position = Vector2(4, 3)
	rows.size = Vector2(124, 106)
	rows.add_theme_constant_override("separation", 1)
	panel.add_child(rows)

	for entry in ACTIONS:
		rows.add_child(_button("%s  %s" % [entry["key"], entry["label"]],
			func(): _run(entry["action"])))
	rows.add_child(_button("Channel overlay", _toggle_overlay))
	rows.add_child(_button("Invincibility", _toggle_invincible))

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 6)
	_status.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	rows.add_child(_status)
	_refresh_status()


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 7)
	b.custom_minimum_size.y = 11
	b.focus_mode = Control.FOCUS_NONE  # never steal WASD/attack input
	b.pressed.connect(on_press)
	return b


func _refresh_status() -> void:
	if _status == null:
		return
	var overlay_on := _overlay != null and _overlay.visible
	var invincible: bool = _gym.is_invincible() if _gym.has_method("is_invincible") else false
	_status.text = "overlay:%s  inv:%s  enemies:%d" % [
		"on" if overlay_on else "off",
		"on" if invincible else "off",
		get_tree().get_nodes_in_group("enemies").size(),
	]
