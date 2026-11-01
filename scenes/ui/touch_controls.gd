extends CanvasLayer
## touch_controls.gd — on-screen stick and buttons for phones/tablets.
##
## Registered as the `TouchControls` autoload, so it floats over EVERY scene
## without any scene knowing about it. It only shows on touch devices (or when
## `force_visible` is ticked, for testing on desktop) and drives the game by
## pressing the same input actions the keyboard does — the game code never
## knows the difference. See docs/systems/touch-controls.md.
##
## Layout is in the 640x360 base-resolution space the game is drawn in.

## Show the overlay even without a touchscreen (desktop testing).
@export var force_visible: bool = false
## On a touch laptop, hide the overlay once a real key is pressed. A touch brings it back.
@export var hide_on_keyboard: bool = true
## Overall opacity of everything drawn.
@export_range(0.0, 1.0) var opacity: float = 0.45

@export_group("Stick")
## Touches that start in the left this-fraction of the screen steer.
@export_range(0.1, 0.8) var stick_zone_width_frac: float = 0.45
## Ignore the top this-fraction of the screen (leaves the HUD tappable).
@export_range(0.0, 0.8) var stick_zone_top_frac: float = 0.2
## Distance a thumb must travel from where it landed for full tilt.
@export var stick_radius_px: float = 40.0
## Fraction of the radius that counts as "centred" (no movement).
@export_range(0.0, 0.9) var dead_zone: float = 0.3
@export var knob_radius_px: float = 16.0
## Where the faint idle ring sits, as fractions of screen width/height.
@export var idle_hint_pos_frac: Vector2 = Vector2(0.22, 0.7)

@export_group("Buttons")
@export var margin_px: float = 14.0
## Primary fire (bottom-right corner).
@export var primary_radius_px: float = 32.0
## Secondary fire (up and left of primary).
@export var secondary_radius_px: float = 26.0
## OK / continue (top-right; presses ui_accept for cards and the picker).
@export var ok_radius_px: float = 20.0
## Gap between neighbouring buttons.
@export var button_gap_px: float = 10.0
## How far secondary sits above primary, as a fraction of primary's radius.
@export var secondary_lift_frac: float = 0.4
@export var label_font_size: int = 18
@export var primary_color: Color = Color(1.0, 0.35, 0.3)
@export var secondary_color: Color = Color(0.35, 0.65, 1.0)
@export var ok_color: Color = Color(0.4, 0.9, 0.5)
@export var stick_color: Color = Color(1, 1, 1)

const _MOVE_ACTIONS := {
	"up": ["move_up", "ui_up"],
	"down": ["move_down", "ui_down"],
	"left": ["move_left", "ui_left"],
	"right": ["move_right", "ui_right"],
}

var _active := false
var _overlay: Control
var _rotate_hint: Label
var _blockers: Array[Control] = []
## {action, center, radius, label, color, touch}; touch = finger index or -1.
var _buttons: Array[Dictionary] = []
var _held: Dictionary = {}  # action name -> true while we hold it down

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO


func _ready() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_rotate_hint = Label.new()
	_rotate_hint.text = "Rotate your phone to landscape"
	_rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_hint.visible = false
	add_child(_rotate_hint)

	get_viewport().size_changed.connect(_layout)
	_set_active(force_visible or DisplayServer.is_touchscreen_available())


func _exit_tree() -> void:
	_release_all()


func _process(_delta: float) -> void:
	if not _active:
		return
	var win := DisplayServer.window_get_size()
	_rotate_hint.visible = win.y > win.x


## Turn the overlay on or off. Off releases anything we were holding.
func _set_active(on: bool) -> void:
	_active = on
	_overlay.visible = on
	if not on:
		_rotate_hint.visible = false
		_release_all()
		_clear_blockers()
	else:
		_layout()
	set_process(on)


func _clear_blockers() -> void:
	for b in _blockers:
		b.queue_free()
	_blockers.clear()


func _layout() -> void:
	if not _active:
		return
	var size := get_viewport().get_visible_rect().size
	var p := Vector2(size.x - margin_px - primary_radius_px, size.y - margin_px - primary_radius_px)
	var s := p + Vector2(-(primary_radius_px + button_gap_px + secondary_radius_px), -(primary_radius_px * secondary_lift_frac))
	var o := Vector2(size.x - margin_px - ok_radius_px, margin_px + ok_radius_px)
	# Keep finger ownership across a re-layout (window resize mid-touch).
	var prev := {}
	for btn in _buttons:
		prev[btn["action"]] = btn["touch"]
	_buttons = [
		{"action": "attack_primary", "center": p, "radius": primary_radius_px, "label": "A", "color": primary_color, "touch": -1},
		{"action": "attack_secondary", "center": s, "radius": secondary_radius_px, "label": "B", "color": secondary_color, "touch": -1},
		{"action": "ui_accept", "center": o, "radius": ok_radius_px, "label": "OK", "color": ok_color, "touch": -1},
	]
	for btn in _buttons:
		btn["touch"] = prev.get(btn["action"], -1)
	# Invisible Controls that swallow the emulated mouse click under each button,
	# so tapping FIRE does not also press a menu button hiding behind it.
	_clear_blockers()
	for btn in _buttons:
		var c := Control.new()
		var r: float = btn["radius"]
		c.position = (btn["center"] as Vector2) - Vector2(r, r)
		c.size = Vector2(r, r) * 2.0
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(c)
		_blockers.append(c)
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		if event is InputEventScreenTouch and DisplayServer.is_touchscreen_available():
			_set_active(true)
		return
	if hide_on_keyboard and not force_visible and event is InputEventKey and event.pressed:
		_set_active(false)
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			_stick_pos = d.position
			_apply_stick()
			_overlay.queue_redraw()


func _touch_down(index: int, pos: Vector2) -> void:
	for btn in _buttons:
		if pos.distance_to(btn["center"]) <= float(btn["radius"]):
			if btn["touch"] == -1:
				btn["touch"] = index
				_set_action(btn["action"], true)
				_overlay.queue_redraw()
			return
	if _stick_touch != -1 or not _in_stick_zone(pos) or _hits_gui_control(pos):
		return
	_stick_touch = index
	_stick_origin = pos
	_stick_pos = pos
	_overlay.queue_redraw()


func _touch_up(index: int) -> void:
	for btn in _buttons:
		if btn["touch"] == index:
			btn["touch"] = -1
			_set_action(btn["action"], false)
			_overlay.queue_redraw()
	if index == _stick_touch:
		_stick_touch = -1
		_apply_stick()
		_overlay.queue_redraw()


func _in_stick_zone(pos: Vector2) -> bool:
	var size := get_viewport().get_visible_rect().size
	return pos.x <= size.x * stick_zone_width_frac and pos.y >= size.y * stick_zone_top_frac


## Turn the stick offset into one of 8 gates and press the matching actions.
func _apply_stick() -> void:
	var want := {"up": false, "down": false, "left": false, "right": false}
	if _stick_touch != -1:
		var v := _stick_pos - _stick_origin
		if v.length() >= stick_radius_px * dead_zone:
			var step := PI / 4.0
			var dir := Vector2.from_angle(roundf(v.angle() / step) * step)
			want["right"] = dir.x > 0.5
			want["left"] = dir.x < -0.5
			want["down"] = dir.y > 0.5
			want["up"] = dir.y < -0.5
	for key: String in want:
		for action: String in _MOVE_ACTIONS[key]:
			_set_action(action, want[key])


func _set_action(action: String, pressed: bool) -> void:
	if pressed == _held.has(action):
		return
	if pressed:
		_held[action] = true
	else:
		_held.erase(action)
	# An InputEventAction both updates Input's polled state (player.gd) and is
	# delivered as an event (menus, picker, between-level cards).
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	_stick_touch = -1
	for btn in _buttons:
		btn["touch"] = -1
	for action: String in _held.keys():
		_set_action(action, false)


## True if a button/slider is under the point, so a tap there stays a UI tap.
func _hits_gui_control(pos: Vector2) -> bool:
	return _scan_for_control(get_tree().root, pos)


func _scan_for_control(node: Node, pos: Vector2) -> bool:
	if node == self:
		return false
	var c := node as Control
	if c != null:
		if not c.is_visible_in_tree():
			return false
		if (c is BaseButton or c is Range) and c.get_global_rect().has_point(pos):
			return true
	for child in node.get_children():
		if _scan_for_control(child, pos):
			return true
	return false


func _draw_overlay() -> void:
	var a := opacity
	var size := get_viewport().get_visible_rect().size
	if _stick_touch != -1:
		var base := stick_color
		base.a = a * 0.5
		_overlay.draw_circle(_stick_origin, stick_radius_px, base)
		var off := (_stick_pos - _stick_origin).limit_length(stick_radius_px)
		var knob := stick_color
		knob.a = a
		_overlay.draw_circle(_stick_origin + off, knob_radius_px, knob)
	else:
		# Idle hint: roughly where a thumb will land.
		var hint := stick_color
		hint.a = a * 0.3
		_overlay.draw_arc(size * idle_hint_pos_frac, stick_radius_px, 0.0, TAU, 32, hint, 2.0)
	var font := ThemeDB.fallback_font
	for btn in _buttons:
		var col: Color = btn["color"]
		col.a = a * (1.6 if btn["touch"] != -1 else 1.0)
		var center: Vector2 = btn["center"]
		_overlay.draw_circle(center, float(btn["radius"]), col)
		var txt: String = btn["label"]
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
		_overlay.draw_string(font, center + Vector2(-ts.x * 0.5, ts.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, Color(1, 1, 1, minf(1.0, a * 2.0)))
