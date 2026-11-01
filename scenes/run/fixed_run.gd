class_name FixedRun
extends Node
## fixed_run.gd — the dumbest possible run: an ordered list of levels, played in order.
##
## (06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md §4.) This node owns the RUN; each level
## (an Encounter) owns one fight. They talk through a single signal: the level
## emits `resolved(outcome, report)`, and this node
##   1. writes the report back into RunState.roster (Encounter only READS RunState),
##   2. on Time's Out, removes random roster members for good,
##   3. frees the finished level,
##   4. shows a card — "next level" or "run over" — and waits for Enter.
##
## The cards live on a CanvasLayer that keeps running even if the tree is paused,
## so they work while the level is gone. No save, no map, no shop (Phase 2).

## The levels, in play order. Drag level scenes from scenes/levels/ in the Inspector.
@export var levels: Array[PackedScene] = []
## Who starts the run, at full health. Order is the order shown in the picker.
@export var starting_roster: Array[CharacterDef] = []
## Half-hearts a mini carried out the exit comes back with next level.
@export var banked_return_half_hearts: int = 2
## Half-hearts a character you failed to rescue comes back with next level
## (the easiest death-permanence tier: they are never lost, just hurt).
@export var downed_return_half_hearts: int = 1
## How many random active characters a Time's Out removes from the run for good.
@export var time_out_removals: int = 1

@export_group("Card look")
@export var card_font_size: int = 12
@export var card_panel_size: Vector2 = Vector2(420, 190)
@export var card_background: Color = Color(0.05, 0.06, 0.08, 0.92)
@export var card_text_color: Color = Color(1, 1, 1)
## Title colour per Encounter.Outcome (CLEARED, ESCAPED, LOST, TIMED_OUT).
@export var outcome_colors: Array[Color] = [
	Color(0.5, 1.0, 0.55), Color(1.0, 0.9, 0.4), Color(1.0, 0.4, 0.4), Color(1.0, 0.6, 0.3)]

enum Card { NONE, BETWEEN, RUN_END }

const OUTCOME_TITLES: Array[String] = ["CLEARED", "ESCAPED", "LOST", "TIME'S OUT"]

var _level_index := -1
var _level: Encounter = null
var _card_kind: int = Card.NONE
var _layer: CanvasLayer = null
var _panel: Panel = null
var _label: RichTextLabel = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_build_card_ui()
	start_run()


func _unhandled_input(event: InputEvent) -> void:
	if _card_kind == Card.NONE or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if _card_kind == Card.BETWEEN:
		_load_level(_level_index + 1)
	else:
		start_run()


## Begin (or restart) the run from level 1 with the starting roster.
func start_run() -> void:
	_free_level()
	RunState.reset()
	for def in starting_roster:
		if def == null:
			continue
		var member := RunState.RosterMember.new()
		member.id = def.resource_path
		member.max_half_hearts = def.max_half_hearts
		member.half_hearts = def.max_half_hearts
		member.status = "active"
		RunState.roster.append(member)
	if levels.is_empty():
		push_error("FixedRun has no levels.")
		return
	_load_level(0)


func _load_level(index: int) -> void:
	_free_level()
	_hide_card()
	_level_index = index
	var scene := levels[index]
	_level = scene.instantiate() as Encounter
	if _level == null:
		push_error("FixedRun level %d is not an Encounter scene." % index)
		return
	_level.resolved.connect(_on_level_resolved, CONNECT_ONE_SHOT)
	add_child(_level)


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null


func _on_level_resolved(outcome: int, report: Dictionary) -> void:
	var lost_names := _apply_report(outcome, report)
	EventBus.encounter_resolved.emit(OUTCOME_TITLES[outcome])
	# The encounter emitted this from inside its own physics step; free it after.
	_free_level()
	var last := _level_index >= levels.size() - 1
	var any_active := _active_count() > 0
	if outcome == Encounter.Outcome.LOST or not any_active or last:
		var won := outcome != Encounter.Outcome.LOST and any_active
		_show_card(Card.RUN_END, outcome, lost_names, won)
	else:
		_show_card(Card.BETWEEN, outcome, lost_names, false)


## Write the level's report into RunState. Returns the display names of anyone
## removed by a Time's Out.
func _apply_report(outcome: int, report: Dictionary) -> Array[String]:
	var survived: Dictionary = report.get("survived", {})
	var banked: Array = report.get("banked", [])
	var downed: Array = report.get("downed", [])
	for member in RunState.roster:
		if member.status != "active":
			continue
		if survived.has(member.id):
			member.half_hearts = clampi(int(survived[member.id]), 1, member.max_half_hearts)
		elif banked.has(member.id):
			member.half_hearts = clampi(banked_return_half_hearts, 1, member.max_half_hearts)
		elif downed.has(member.id):
			member.half_hearts = clampi(downed_return_half_hearts, 1, member.max_half_hearts)
	var removed: Array[String] = []
	if outcome == Encounter.Outcome.TIMED_OUT:
		var candidates: Array = RunState.roster.filter(func(m): return m.status == "active")
		candidates.shuffle()
		for i in mini(time_out_removals, candidates.size()):
			candidates[i].status = "lost"
			removed.append(_name_of(candidates[i].id))
	return removed


func _active_count() -> int:
	var n := 0
	for member in RunState.roster:
		if member.status == "active":
			n += 1
	return n


func _name_of(id: String) -> String:
	var def := load(id) as CharacterDef
	return def.display_name if def != null and def.display_name != "" else id.get_file()


# --- Cards ---------------------------------------------------------------------

func _build_card_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_panel = Panel.new()
	_panel.size = card_panel_size
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = card_background
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = false
	_label.position = Vector2(12, 8)
	_label.size = card_panel_size - Vector2(24, 16)
	_label.add_theme_font_size_override("normal_font_size", card_font_size)
	_label.add_theme_font_size_override("bold_font_size", card_font_size)
	_label.add_theme_color_override("default_color", card_text_color)
	_panel.add_child(_label)


func _roster_lines() -> String:
	var lines := ""
	for member in RunState.roster:
		var status := "%d / %d" % [member.half_hearts, member.max_half_hearts]
		if member.status != "active":
			status = "LOST"
		lines += "  %s   %s\n" % [_name_of(member.id), status]
	return lines


func _show_card(kind: int, outcome: int, lost_names: Array[String], won: bool) -> void:
	_card_kind = kind
	var color: Color = outcome_colors[outcome] if outcome < outcome_colors.size() else card_text_color
	var title := OUTCOME_TITLES[outcome]
	var text := "[color=#%s][b]%s[/b][/color]\n" % [color.to_html(false), title]
	if not lost_names.is_empty():
		text += "[color=#ff8866]Removed from the run: %s[/color]\n" % ", ".join(lost_names)
	text += "\nRoster (half-hearts):\n" + _roster_lines()
	if kind == Card.BETWEEN:
		text += "\nNext: %s\n[b]Enter to continue[/b]" % _level_title(_level_index + 1)
	else:
		text += "\n[b]%s[/b]   Enter to restart the run" % ("RUN COMPLETE" if won else "RUN OVER")
	_label.text = text
	_panel.position = (get_viewport().get_visible_rect().size - card_panel_size) * 0.5
	_panel.visible = true


func _hide_card() -> void:
	_card_kind = Card.NONE
	_panel.visible = false


## The next level's display_name, read without keeping the instance around.
func _level_title(index: int) -> String:
	if index < 0 or index >= levels.size():
		return "?"
	var state := levels[index].get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == "display_name":
			return str(state.get_node_property_value(0, i))
	# display_name lives on an inherited scene: fall back to the file name.
	return levels[index].resource_path.get_file().get_basename()
