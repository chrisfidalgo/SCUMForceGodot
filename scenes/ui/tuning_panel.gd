extends CanvasLayer
## tuning_panel.gd — an in-play tuning panel (press the ` / ~ key to toggle).
##
## A CanvasLayer draws its children in screen space, above the game, regardless
## of the world camera — perfect for debug UI. This panel exposes the live
## projectile/height knobs (CombatTuning) and the active character's two
## AttackDefs as mouse sliders, so values can be dialed in WITHOUT leaving play
## mode. "Log values" prints the current numbers to the console so good settings
## can be copied back into the .tres files. Nothing here ships in a real build.
##
## ANYTHING can put its own knobs in this panel — it is not player-only. Add the
## node to the "tunable" group and implement whichever of these you need:
##
##   get_tuning_label()   -> String              a header for your section
##   get_tuning_attacks() -> Array[AttackDef]    attacks to expose (optional)
##   get_tuning_spec()    -> Array[Dictionary]   plain numbers to expose (optional)
##        each entry: {"property": "move_speed", "min": 10.0, "max": 200.0, "step": 5.0}
##
## That is the whole contract. An enemy exposes its fire cooldown and preferred
## range by implementing get_tuning_spec() and joining the group — no edit to
## this file. Keeping the seam here means packets that add tunable things never
## have to touch a shared script (01-AGENT-BRIEFING.md, parallel-work rules).

const TOGGLE_KEYCODE := KEY_QUOTELEFT  # the ` / ~ key

var _rows: VBoxContainer
var _root: Control

func _ready() -> void:
	_build_shell()
	_root.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEYCODE:
		_root.visible = not _root.visible
		if _root.visible:
			_rebuild_rows()

func _build_shell() -> void:
	_root = Panel.new()
	_root.position = Vector2(6, 6)
	_root.size = Vector2(226, 346)
	add_child(_root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m, 5)
	_root.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.custom_minimum_size.x = 208
	scroll.add_child(_rows)

func _rebuild_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_header("TUNING  ( ` to close )")

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.character_def != null:
		var prim: AttackDef = player.character_def.primary_attack
		if prim != null:
			_header("PRIMARY — %s" % player.character_def.display_name)
			_attack_rows(prim)
		var sec: AttackDef = player.character_def.secondary_attack
		if sec != null:
			_header("SECONDARY")
			_attack_rows(sec)

	for node in get_tree().get_nodes_in_group("tunable"):
		_tunable_rows(node)

	_header("GLOBAL (projectile/height)")
	_slider("shadow radius", CombatTuning.shadow_base_radius, 2, 20, 0.5, func(v): CombatTuning.shadow_base_radius = v)
	_slider("shadow alpha", CombatTuning.shadow_alpha, 0, 1, 0.05, func(v): CombatTuning.shadow_alpha = v)
	_slider("height scale", CombatTuning.height_scale_per_unit, 0, 0.1, 0.005, func(v): CombatTuning.height_scale_per_unit = v)
	_slider("tail gap", CombatTuning.tail_gap_px, 0, 20, 0.5, func(v): CombatTuning.tail_gap_px = v)
	_slider("tail fps", CombatTuning.tail_fps, 1, 30, 1, func(v): CombatTuning.tail_fps = v)
	_slider("ground<->both", CombatTuning.height_ground_max, 0, 12, 0.5, func(v): CombatTuning.height_ground_max = v)
	_slider("both<->high", CombatTuning.height_high_min, 4, 30, 0.5, func(v): CombatTuning.height_high_min = v)

	var log_btn := Button.new()
	log_btn.text = "Log values to console"
	log_btn.add_theme_font_size_override("font_size", 7)
	log_btn.pressed.connect(_log_values)
	_rows.add_child(log_btn)

## Render one "tunable" group member: its label, its attacks, its plain numbers.
func _tunable_rows(node: Object) -> void:
	if node == null or not is_instance_valid(node):
		return
	var label := "TUNABLE"
	if node.has_method("get_tuning_label"):
		label = str(node.call("get_tuning_label"))
	var attacks: Array = []
	if node.has_method("get_tuning_attacks"):
		attacks = node.call("get_tuning_attacks")
	var spec: Array = []
	if node.has_method("get_tuning_spec"):
		spec = node.call("get_tuning_spec")
	if attacks.is_empty() and spec.is_empty():
		return
	_header(label)
	for a in attacks:
		if a is AttackDef:
			_attack_rows(a)
	for entry in spec:
		_spec_slider(node, entry)

## One slider bound to a plain property on a node, described by a spec entry.
func _spec_slider(node: Object, entry: Dictionary) -> void:
	var prop: String = str(entry.get("property", ""))
	if prop == "":
		return
	var current: Variant = node.get(prop)
	if not (current is float or current is int):
		push_warning("tuning_panel: %s.%s is not a number, skipped." % [node, prop])
		return
	_slider(prop, float(current),
		float(entry.get("min", 0.0)), float(entry.get("max", 100.0)),
		float(entry.get("step", 1.0)),
		func(v): node.set(prop, v))

func _attack_rows(a: AttackDef) -> void:
	_slider("speed", a.projectile_speed, 40, 600, 5, func(v): a.projectile_speed = v)
	_slider("range", a.range_px, 30, 400, 5, func(v): a.range_px = v)
	if a.height_profile != AttackDef.HeightProfile.GROUND:
		_slider("lob peak", a.lob_peak_height, 4, 40, 0.5, func(v): a.lob_peak_height = v)
	if a.lateral_motion == AttackDef.LateralMotion.SINE:
		_slider("sine amp", a.sine_amplitude_px, 0, 24, 0.5, func(v): a.sine_amplitude_px = v)
		_slider("sine wavelen", a.sine_wavelength_px, 8, 120, 2, func(v): a.sine_wavelength_px = v)
	_slider("damage", a.damage_half_hearts, 1, 8, 1, func(v): a.damage_half_hearts = int(v))
	_slider("cooldown", a.cooldown_sec, 0.05, 2.5, 0.05, func(v): a.cooldown_sec = v)

func _header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_rows.add_child(lbl)

## One labelled slider. `setter` is called with the new value on drag.
func _slider(label_text: String, initial: float, min_v: float, max_v: float, step: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.custom_minimum_size.x = 78
	name_lbl.add_theme_font_size_override("font_size", 7)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 86
	var val_lbl := Label.new()
	val_lbl.text = _fmt(initial)
	val_lbl.custom_minimum_size.x = 32
	val_lbl.add_theme_font_size_override("font_size", 7)
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		val_lbl.text = _fmt(v))
	row.add_child(name_lbl)
	row.add_child(slider)
	row.add_child(val_lbl)
	_rows.add_child(row)

func _fmt(v: float) -> String:
	return str(snappedf(v, 0.01))

func _log_values() -> void:
	print("--- TUNING SNAPSHOT ---")
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.character_def != null:
		_log_attack("primary", player.character_def.primary_attack)
		_log_attack("secondary", player.character_def.secondary_attack)
	for node in get_tree().get_nodes_in_group("tunable"):
		if not is_instance_valid(node):
			continue
		var label := str(node.call("get_tuning_label")) if node.has_method("get_tuning_label") else str(node)
		if node.has_method("get_tuning_attacks"):
			for a in node.call("get_tuning_attacks"):
				if a is AttackDef:
					_log_attack(label, a)
		if node.has_method("get_tuning_spec"):
			for entry in node.call("get_tuning_spec"):
				var prop: String = str(entry.get("property", ""))
				if prop != "":
					print("%s: %s=%s" % [label, prop, node.get(prop)])
	print("CombatTuning: shadow_base_radius=%s shadow_alpha=%s height_scale_per_unit=%s tail_gap_px=%s tail_fps=%s height_ground_max=%s height_high_min=%s" % [
		CombatTuning.shadow_base_radius, CombatTuning.shadow_alpha, CombatTuning.height_scale_per_unit,
		CombatTuning.tail_gap_px, CombatTuning.tail_fps, CombatTuning.height_ground_max, CombatTuning.height_high_min])

func _log_attack(slot: String, a: AttackDef) -> void:
	if a == null:
		return
	print("%s: speed=%s range=%s lob_peak=%s sine_amp=%s sine_wavelen=%s damage=%d cooldown=%s" % [
		slot, a.projectile_speed, a.range_px, a.lob_peak_height, a.sine_amplitude_px,
		a.sine_wavelength_px, a.damage_half_hearts, a.cooldown_sec])
