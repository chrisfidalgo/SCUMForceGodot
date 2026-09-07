extends Node2D
## channel_overlay.gd — the F-key channel visualisation (03-GYM-SPEC.md §5).
##
## Draws a coloured outline around every hurtbox and blocker in the arena, tinted
## by which channel it belongs to:
##
##   LOW  = orange   (only a LOW attack reaches / stops here)
##   HIGH = blue     (only a HIGH attack reaches / stops here)
##   BOTH = purple   (either)
##
## This exists because the channel system is the game's identity and is otherwise
## completely invisible — a player who cannot see why their shot passed over an
## enemy learns nothing from it. Turning this on should make the whole §7.4/§7.5
## matrix legible at a glance, which is the fastest way to spot a mis-set layer.
##
## It is also a prototype of possible player-facing readability UI, so it is
## worth judging on looks as well as correctness.
##
## Hidden by default; the debug tray toggles `visible`.

const LAYER_HURT_LOW := 8      ## bit for physics layer 4
const LAYER_HURT_HIGH := 16    ## layer 5
const LAYER_BLOCK_LOW := 32    ## layer 6
const LAYER_BLOCK_HIGH := 64   ## layer 7

const COLOR_LOW := Color(1.0, 0.55, 0.1, 0.9)
const COLOR_HIGH := Color(0.3, 0.6, 1.0, 0.9)
const COLOR_BOTH := Color(0.75, 0.4, 1.0, 0.9)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for area in _all_areas(get_tree().current_scene):
		var layer := area.collision_layer
		var low := (layer & (LAYER_HURT_LOW | LAYER_BLOCK_LOW)) != 0
		var high := (layer & (LAYER_HURT_HIGH | LAYER_BLOCK_HIGH)) != 0
		if not low and not high:
			continue
		var color := COLOR_BOTH if (low and high) else (COLOR_LOW if low else COLOR_HIGH)
		# A blocker is drawn dashed-ish (thinner) so it reads differently from a
		# thing you can damage.
		var is_blocker := (layer & (LAYER_BLOCK_LOW | LAYER_BLOCK_HIGH)) != 0
		_draw_area(area, color, 1.0 if is_blocker else 2.0)


## Outline one area's collision shapes, in this node's local space.
func _draw_area(area: Area2D, color: Color, width: float) -> void:
	for child in area.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var center: Vector2 = to_local(cs.global_position)
		if cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			draw_rect(Rect2(center - size * 0.5, size), color, false, width)
		elif cs.shape is CircleShape2D:
			draw_arc(center, (cs.shape as CircleShape2D).radius, 0.0, TAU, 20, color, width)


## Every Area2D under `root`. A debug overlay scanning the tree each frame is
## fine at gym scale; do not copy this pattern into gameplay code.
func _all_areas(root: Node) -> Array[Area2D]:
	var found: Array[Area2D] = []
	if root == null:
		return found
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Area2D:
			found.append(node)
		for child in node.get_children():
			stack.append(child)
	return found
