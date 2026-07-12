class_name Projectile
extends Area2D
## Projectile — a traveling attack instance, spawned by AttackSpawner from an
## AttackDef's data (never hardcode one attack's numbers here).
##
## An Area2D is a node that reports "something overlapped me" without any
## physical push/collision response — exactly what a projectile needs: it
## should pass through anything not on its channel and stop cleanly on the
## first thing that is. `collision_mask` (which layers this node can detect)
## is derived from the attack's channel via ChannelMasks — that one mapping
## is what makes LOW/HIGH/BOTH a real physics rule instead of a script check.

## Placeholder look (a flat dot colored by channel) until real art exists.
@export var visual_radius: float = 4.0

var _direction := Vector2.ZERO
var _speed := 0.0
var _max_range := 0.0
var _damage_half_hearts := 0
var _channel: AttackDef.Channel = AttackDef.Channel.LOW
var _ignore_node: Node = null
var _distance_traveled := 0.0

## Configure this projectile. Call BEFORE add_child() so collision_mask and
## movement data are already correct the first time physics processes it.
func setup(
	direction: Vector2,
	speed: float,
	max_range: float,
	channel: AttackDef.Channel,
	damage_half_hearts: int,
	ignore_node: Node = null
) -> void:
	_direction = direction
	_speed = speed
	_max_range = max_range
	_damage_half_hearts = damage_half_hearts
	_channel = channel
	_ignore_node = ignore_node
	collision_layer = 0
	collision_mask = ChannelMasks.mask_for_channel(channel)
	queue_redraw()

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var step: Vector2 = _direction * _speed * delta
	global_position += step
	_distance_traveled += step.length()
	if _distance_traveled >= _max_range:
		queue_free()

## A hurtbox (has receive_hit) takes damage and the shot expires; a blocker
## (no receive_hit — a structure on block_low/block_high) just stops it. See
## 02-ARCHITECTURE.md §4: "stopped by whichever blocker it hits first."
func _on_area_entered(area: Area2D) -> void:
	if _is_ignored(area):
		return
	var target: Object = _resolve_hurt_target(area)
	if target != null:
		target.receive_hit(_damage_half_hearts)
	queue_free()

## A hurtbox may carry receive_hit() on the Area2D itself, or (the common Godot
## pattern) be a scriptless Area2D child whose owning entity carries it. Resolve
## either. Anything with no receive_hit anywhere is a blocker — we still expire.
func _resolve_hurt_target(area: Area2D) -> Object:
	if area.has_method("receive_hit"):
		return area
	if area.owner != null and area.owner.has_method("receive_hit"):
		return area.owner
	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("receive_hit"):
		return parent
	return null

func _is_ignored(area: Area2D) -> bool:
	if _ignore_node == null:
		return false
	return area == _ignore_node or _ignore_node.is_ancestor_of(area)

func _draw() -> void:
	draw_circle(Vector2.ZERO, visual_radius, ChannelMasks.debug_color(_channel))
