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
## on F1..F6). F1 spawns the selected enemy type, F2/F3 cycle the type, and
## down/swap/reset fill the rest, so the channel overlay and invincibility are
## button-only. If they earn a hotkey during playtesting, that is a request to
## the orchestrator to unfreeze one input, not something to patch in here.

## Enemy types are every EnemyDef found here at runtime — drop in a new `.tres`
## and it appears in the F2/F3 cycle with no code change.
const ENEMY_DIR := "res://resources/enemies/"

const ACTIONS := [
	{"action": "debug_1", "key": "F1", "label": "Spawn enemy"},
	{"action": "debug_2", "key": "F2", "label": "Next type >"},
	{"action": "debug_3", "key": "F3", "label": "< Prev type"},
	{"action": "debug_4", "key": "F4", "label": "Force down"},
	{"action": "debug_5", "key": "F5", "label": "Swap character"},
	{"action": "debug_6", "key": "F6", "label": "Reset gym"},
]

var _gym: Node = null
var _overlay: Node2D = null
var _status: Label = null
var _type_label: Label = null
var _enemy_types: Array[EnemyDef] = []
var _type_index := 0


func _ready() -> void:
	_gym = get_parent()
	# See combat_hud.gd: the parent gym is not ready yet when a child readies.
	if not _gym.is_node_ready():
		await _gym.ready
	_overlay = _gym.get_node_or_null("ChannelOverlay")
	_load_enemy_types()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	for entry in ACTIONS:
		if event.is_action_pressed(entry["action"]):
			_run(entry["action"])
			get_viewport().set_input_as_handled()
			return


func _run(action: String) -> void:
	match action:
		"debug_1":
			if not _enemy_types.is_empty():
				_gym.spawn_enemy(_enemy_types[_type_index], Enemy.Elevation.GROUND,
					Vector2.INF, _gym.get_node_or_null("PatrolRoute"))
		"debug_2": _cycle_type(1)
		"debug_3": _cycle_type(-1)
		"debug_4": _gym.debug_force_down()
		"debug_5": _gym.debug_swap_character()
		"debug_6": _gym.debug_reset()
	_refresh_status()


func _cycle_type(step: int) -> void:
	if _enemy_types.is_empty():
		return
	_type_index = posmod(_type_index + step, _enemy_types.size())


## Build the type list from the folder at runtime. Exported builds rename
## resources to `<name>.tres.remap`, so strip that before loading.
func _load_enemy_types() -> void:
	_enemy_types.clear()
	var names: Array[String] = []
	for file in DirAccess.get_files_at(ENEMY_DIR):
		var clean := file.trim_suffix(".remap")
		if (clean.ends_with(".tres") or clean.ends_with(".res")) and not names.has(clean):
			names.append(clean)
	names.sort()
	for clean in names:
		var type_def := load(ENEMY_DIR + clean) as EnemyDef
		if type_def != null:
			_enemy_types.append(type_def)
	for i in _enemy_types.size():
		if _enemy_types[i].display_name == "Wanderer":
			_type_index = i  # the old F1 default
			break
	if _enemy_types.is_empty():
		push_warning("debug_tray: no EnemyDef resources found in %s" % ENEMY_DIR)


func _selected_type_name() -> String:
	if _enemy_types.is_empty():
		return "(none)"
	var type_def := _enemy_types[_type_index]
	return type_def.display_name if type_def.display_name != "" else "(unnamed)"


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
	panel.position = Vector2(6, 360 - 130)
	panel.size = Vector2(132, 124)
	add_child(panel)

	var rows := VBoxContainer.new()
	rows.position = Vector2(4, 3)
	rows.size = Vector2(124, 118)
	rows.add_theme_constant_override("separation", 1)
	panel.add_child(rows)

	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 7)
	_type_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	rows.add_child(_type_label)

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
	_type_label.text = "Type: %s" % _selected_type_name()
	var overlay_on := _overlay != null and _overlay.visible
	var invincible: bool = _gym.is_invincible() if _gym.has_method("is_invincible") else false
	_status.text = "overlay:%s  inv:%s  enemies:%d" % [
		"on" if overlay_on else "off",
		"on" if invincible else "off",
		get_tree().get_nodes_in_group("enemies").size(),
	]
