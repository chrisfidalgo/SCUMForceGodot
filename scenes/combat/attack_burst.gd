class_name AttackBurst
extends Area2D
## AttackBurst — a one-instant, self-centered radial hit for FIXED-aim
## attacks (Rind Slam): no travel, no aiming — everything on the attack's
## channel within range_px of the caster takes damage once, then it's gone.
##
## Built entirely in code by AttackSpawner (no matching .tscn) because it's
## just a circle sized per-call from AttackDef.range_px; there's nothing to
## hand-author in the editor.

var _damage_half_hearts := 0
var _ignore_node: Node = null
var _hit_areas: Array[Area2D] = []

## Configure this burst. Call BEFORE add_child() — see Projectile.setup()
## for why (collision data must be correct before physics ever sees it).
func setup(
	channel: AttackDef.Channel,
	radius: float,
	damage_half_hearts: int,
	ignore_node: Node = null
) -> void:
	_damage_half_hearts = damage_half_hearts
	_ignore_node = ignore_node
	collision_layer = 0
	collision_mask = ChannelMasks.mask_for_channel(channel)
	monitoring = true
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)
	area_entered.connect(_on_area_entered)

## Call once this node is positioned in the world (after add_child() +
## setting global_position). Two physics frames is enough for the physics
## server to register overlaps against a shape that only just started
## existing; then the burst is done — it's an instant, not a hazard.
func detonate() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area in _hit_areas:
		return
	if _ignore_node != null and (area == _ignore_node or _ignore_node.is_ancestor_of(area)):
		return
	var target: Object = _resolve_hurt_target(area)
	if target != null:
		_hit_areas.append(area)
		target.receive_hit(_damage_half_hearts)

## Matches Projectile._resolve_hurt_target: receive_hit may live on the Area2D
## or on the entity that owns it. Blockers (no receive_hit anywhere) are ignored.
func _resolve_hurt_target(area: Area2D) -> Object:
	if area.has_method("receive_hit"):
		return area
	if area.owner != null and area.owner.has_method("receive_hit"):
		return area.owner
	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("receive_hit"):
		return parent
	return null
