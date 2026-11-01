class_name DeployPicker
extends CanvasLayer
## deploy_picker.gd — "who goes in?" character select shown between deploys.
##
## Shows ONE character at a time: big portrait, name, health in hearts, an up
## arrow above and a down arrow below, and a "1 / 2" counter. Cycle with
## up/down (W/S, arrow keys, or tap the arrows); deploy with Enter / J, a tap
## or click on the portrait, or a number key (1 = first choice, ...).
##
## The Encounter pauses the whole tree while this is up (choosing is never under
## fire), so this node runs with process_mode ALWAYS or it could not hear input.
## The Encounter listens for `picked` and does the actual deploying.
##
## Health is shown in HALF-hearts (two pips = one heart), the game's damage unit.

## The player chose someone.
signal picked(def: CharacterDef)

@export var title_text: String = "WHO GOES IN?"
@export var hint_text: String = "▲▼ choose · Enter / J deploy"
@export var font_size: int = 10
@export var title_font_size: int = 12
## Portrait box (screen px at 640x360). Also the tap-to-deploy hit area.
@export var portrait_size_px: float = 120.0
## Arrow buttons — kept big so thumbs can hit them.
@export var arrow_size_px: Vector2 = Vector2(140.0, 36.0)
@export var arrow_color: Color = Color(1.0, 0.9, 0.3)
## Size of one half-heart pip and the gap between pips.
@export var heart_pip_px: Vector2 = Vector2(6.0, 12.0)
@export var heart_gap_px: float = 2.0
@export var heart_full_color: Color = Color(0.9, 0.25, 0.3)
@export var heart_empty_color: Color = Color(0.25, 0.15, 0.18)
@export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.8)
@export var vertical_spacing_px: int = 4
## Confirm presses are ignored this long after the picker opens, so the Enter /
## click that closed the previous card cannot also pick a character.
@export var confirm_arm_delay_sec: float = 0.3

var _choices: Array[CharacterDef] = []
var _hp_by_path: Dictionary = {}
var _index := 0
var _opened_at_msec := 0

var _root: Control = null
var _portrait: TextureRect = null
var _portrait_fallback: ColorRect = null
var _name_label: Label = null
var _hearts: Control = null
var _counter_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_build_ui()
	_root.visible = false
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", vertical_spacing_px)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	col.add_child(_label(title_text, title_font_size))
	col.add_child(_arrow_button(true))

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(portrait_size_px, portrait_size_px)
	portrait_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(portrait_box)
	_portrait_fallback = ColorRect.new()
	_portrait_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(_portrait_fallback)
	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(_portrait)
	# Invisible button over the portrait = tap/click to deploy.
	var deploy_btn := Button.new()
	deploy_btn.flat = true
	deploy_btn.focus_mode = Control.FOCUS_NONE
	deploy_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	deploy_btn.pressed.connect(_confirm)
	portrait_box.add_child(deploy_btn)

	_name_label = _label("", title_font_size)
	col.add_child(_name_label)

	_hearts = Control.new()
	_hearts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hearts)

	_counter_label = _label("", font_size)
	col.add_child(_counter_label)
	col.add_child(_arrow_button(false))
	col.add_child(_label(hint_text, font_size))


## Show the choices. `hp_by_path` maps CharacterDef.resource_path -> half-hearts left.
func present(choices: Array[CharacterDef], hp_by_path: Dictionary) -> void:
	_choices = choices.duplicate()
	_hp_by_path = hp_by_path
	_index = 0
	_opened_at_msec = Time.get_ticks_msec()
	_show_current()
	_root.visible = true
	visible = true


func dismiss() -> void:
	_choices.clear()
	visible = false
	if _root != null:
		_root.visible = false


## Move the selection by `step` (+1 = down, -1 = up), wrapping around.
func cycle(step: int) -> void:
	if _choices.is_empty():
		return
	_index = posmod(_index + step, _choices.size())
	_show_current()


func _show_current() -> void:
	if _choices.is_empty():
		return
	var def := _choices[_index]
	var tex: Texture2D = def.portrait
	_portrait.texture = tex
	# Enlarged pixel art stays crisp; big art shrunk down is smoothed.
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST \
			if tex != null and tex.get_width() <= portrait_size_px \
			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait_fallback.color = def.placeholder_color
	_portrait_fallback.visible = tex == null
	_name_label.text = def.display_name
	_counter_label.text = "%d / %d" % [_index + 1, _choices.size()]
	var hp: int = _hp_by_path.get(def.resource_path, def.max_half_hearts)
	_rebuild_hearts(hp, def.max_half_hearts)


func _rebuild_hearts(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		_hearts.remove_child(child)
		child.queue_free()
	var step := heart_pip_px.x + heart_gap_px
	for i in maximum:
		var pip := ColorRect.new()
		pip.size = heart_pip_px
		pip.position = Vector2(i * step + (i / 2) * heart_gap_px, 0.0)
		pip.color = heart_full_color if i < current else heart_empty_color
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts.add_child(pip)
	var width := maximum * step + (maximum / 2) * heart_gap_px
	_hearts.custom_minimum_size = Vector2(width, heart_pip_px.y)


func _input(event: InputEvent) -> void:
	if not visible or _choices.is_empty():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			var index: int = key.keycode - KEY_1
			if index >= 0 and index < _choices.size():
				get_viewport().set_input_as_handled()
				_pick(index)
				return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_up") or event.is_action("move_up"):
		get_viewport().set_input_as_handled()
		cycle(-1)
	elif event.is_action("ui_down") or event.is_action("move_down"):
		get_viewport().set_input_as_handled()
		cycle(1)
	elif event.is_action("ui_accept") or event.is_action("attack_primary"):
		get_viewport().set_input_as_handled()
		_confirm()


## Deploy whoever is on screen (ignored for a moment after opening).
func _confirm() -> void:
	if float(Time.get_ticks_msec() - _opened_at_msec) < confirm_arm_delay_sec * 1000.0:
		return
	_pick(_index)


func _pick(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	var def := _choices[index]
	dismiss()
	picked.emit(def)


## A big triangle button: `up` true = ▲ (previous), false = ▼ (next). The
## triangle is drawn as a polygon so it does not depend on font glyphs.
func _arrow_button(up: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = arrow_size_px
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cycle.bind(-1 if up else 1))
	var tri := Polygon2D.new()
	var cx := arrow_size_px.x * 0.5
	var cy := arrow_size_px.y * 0.5
	var hw := arrow_size_px.y * 0.5
	var hh := arrow_size_px.y * 0.25
	if up:
		tri.polygon = PackedVector2Array([Vector2(cx, cy - hh), Vector2(cx + hw, cy + hh), Vector2(cx - hw, cy + hh)])
	else:
		tri.polygon = PackedVector2Array([Vector2(cx, cy + hh), Vector2(cx + hw, cy - hh), Vector2(cx - hw, cy - hh)])
	tri.color = arrow_color
	b.add_child(tri)
	return b


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
