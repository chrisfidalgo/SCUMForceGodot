class_name DeployPicker
extends CanvasLayer
## deploy_picker.gd — "who goes in?" menu shown between deploys.
##
## The Encounter pauses the whole tree while this is up (choosing is never under
## fire), so this node runs with process_mode ALWAYS or it could not hear the
## click. Pick with the number keys or by clicking a button; the Encounter
## listens for `picked` and does the actual deploying.
##
## Health is shown in HALF-hearts ("3 / 4"), the game's damage unit.

## The player chose someone.
signal picked(def: CharacterDef)

@export var title_text: String = "WHO GOES IN?"
@export var panel_width_px: float = 220.0
@export var font_size: int = 8

var _choices: Array[CharacterDef] = []
var _rows: VBoxContainer = null
var _panel: Panel = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_panel = Panel.new()
	_panel.visible = false
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.position = Vector2(8, 6)
	_rows.size = Vector2(panel_width_px - 16.0, 0.0)
	_panel.add_child(_rows)
	visible = false


## Show the choices. `hp_by_path` maps CharacterDef.resource_path -> half-hearts left.
func present(choices: Array[CharacterDef], hp_by_path: Dictionary) -> void:
	_choices = choices.duplicate()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(_label(title_text))
	_rows.add_child(_label("number key or click   (HP in half-hearts)"))
	for i in _choices.size():
		var def := _choices[i]
		var hp: int = hp_by_path.get(def.resource_path, def.max_half_hearts)
		var b := Button.new()
		b.text = "%d   %s    HP %d / %d" % [i + 1, def.display_name, hp, def.max_half_hearts]
		b.add_theme_font_size_override("font_size", font_size)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		_rows.add_child(b)
	var height := 12.0 + 14.0 * (_choices.size() + 2)
	_panel.size = Vector2(panel_width_px, height)
	var screen := get_viewport().get_visible_rect().size
	_panel.position = (screen - _panel.size) * 0.5
	_panel.visible = true
	visible = true


func dismiss() -> void:
	_choices.clear()
	visible = false
	if _panel != null:
		_panel.visible = false


func _input(event: InputEvent) -> void:
	if not visible or _choices.is_empty():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index >= 0 and index < _choices.size():
		get_viewport().set_input_as_handled()
		_pick(index)


func _pick(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	var def := _choices[index]
	dismiss()
	picked.emit(def)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l
