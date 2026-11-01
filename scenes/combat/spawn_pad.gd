@tool
class_name SpawnPad
extends Node2D
## spawn_pad.gd — marks where characters deploy (a child of PlayerSpawn).
##
## While nobody is on the field (the picker is up, or between characters) it
## pulses with a label, so the player can see where they are about to land and
## what is already standing near it. Once someone deploys it fades to a faint
## ring. The Encounter flips `awaiting`; the pad itself has no game logic.
##
## @tool so it also draws in the editor — a level designer sees the spawn point
## without running the scene.

## True while waiting for a deploy. Set by the Encounter.
var awaiting: bool = true:
	set(value):
		awaiting = value
		queue_redraw()

@export var radius_px: float = 14.0
@export var ring_width_px: float = 2.0
@export var color: Color = Color(0.35, 0.85, 1.0)
## Fill opacity at the bright end of the pulse while awaiting.
@export_range(0.0, 1.0, 0.05) var awaiting_fill_alpha: float = 0.35
## Ring opacity once a character is on the field.
@export_range(0.0, 1.0, 0.05) var deployed_ring_alpha: float = 0.2
## Pulses per second while awaiting.
@export var pulse_hz: float = 1.2
@export var label_text: String = "START"
@export var label_font_size: int = 8
## Gap between the ring and the label above it.
@export var label_gap_px: float = 4.0

var _time := 0.0


func _ready() -> void:
	# Keep pulsing while the tree is paused for the character picker.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if awaiting or Engine.is_editor_hint():
		_time += delta
		queue_redraw()


func _draw() -> void:
	if awaiting or Engine.is_editor_hint():
		var pulse := 0.5 + 0.5 * sin(_time * TAU * pulse_hz)
		var fill := color
		fill.a = awaiting_fill_alpha * (0.4 + 0.6 * pulse)
		draw_circle(Vector2.ZERO, radius_px * (1.0 + 0.15 * pulse), fill)
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 32, color, ring_width_px)
		var font := ThemeDB.fallback_font
		var size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, label_font_size)
		draw_string(font, Vector2(-size.x * 0.5, -radius_px - label_gap_px), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, color)
	else:
		var faint := color
		faint.a = deployed_ring_alpha
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 32, faint, ring_width_px)
