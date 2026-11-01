@tool
class_name PatrolRoute
extends Node2D
## patrol_route.gd — optional helper: attach to a plain Node2D whose Marker2D
## children are patrol waypoints, and the route is drawn in the editor (and,
## if `show_in_game` is on, while playing). Enemies do not need this script —
## any Node2D with Marker2D children works as a route.

@export var line_color: Color = Color(0.3, 0.9, 1.0, 0.8)
@export var show_in_game: bool = false
## Close the loop back to the first point (match the enemy def's LOOP mode).
@export var closed: bool = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		return
	var points: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			points.append(to_local((child as Marker2D).global_position))
	for i in points.size():
		draw_circle(points[i], 3.0, line_color)
		if i + 1 < points.size():
			draw_line(points[i], points[i + 1], line_color, 1.0)
	if closed and points.size() > 2:
		draw_line(points[points.size() - 1], points[0], line_color, 1.0)
