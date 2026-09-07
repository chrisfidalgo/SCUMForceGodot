class_name Projectile
extends Area2D
## Projectile — a traveling attack instance, configured from an AttackDef.
##
## An Area2D reports overlaps without physically blocking. This projectile
## always lives at GROUND position (its collision happens there); a simulated
## `height` scalar drives three things instead of any real 3D:
##   1. its live collision channel — near-ground = LOW, mid = BOTH, peak = HIGH
##      (ChannelMasks.channel_for_height), so a lob physically ignores a low
##      wall's block_low layer while it's high, then hits ground targets as it
##      lands. That IS the "lob over the wall" rule (04-COMBAT-MODEL.md §2).
##   2. the sprite's upward lift + scale (sells the arc), and
##   3. an oval ground shadow that shrinks/fades as height rises.
## Because the mask changes mid-flight we resolve hits by polling overlaps each
## physics frame rather than relying on the one-shot area_entered signal.

## Projectile visual tuning (shadow, scale, trail) lives on CombatTuning so the
## in-play tuning panel can adjust it live. Per-attack numbers are on AttackDef.

var _attack: AttackDef
var _direction := Vector2.UP
var _speed := 0.0
var _max_range := 0.0
var _damage := 0
var _ignore: Node = null

var _height := 0.0
var _distance := 0.0
var _base_position := Vector2.ZERO
var _channel: AttackDef.Channel = AttackDef.Channel.LOW
## Whose shot this is. The hurt layers encode height, not side, so without this
## an enemy's projectile would damage the enemy standing in front of it.
var _source_faction: Faction.Team = Faction.Team.NEUTRAL
var _consumed := false
var _started := false
var _tail_time := 0.0

@onready var _visual: Node2D = $Visual
@onready var _tail: Sprite2D = get_node_or_null("Visual/Tail")

## Configure from the AttackDef. Call BEFORE add_child() so the mask is correct
## before physics first sees it. `direction` is the (already 8-gated) facing.
func setup(attack: AttackDef, direction: Vector2, source: Node) -> void:
	_attack = attack
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	_speed = attack.projectile_speed
	_max_range = attack.range_px
	_damage = attack.damage_half_hearts
	_ignore = source
	_source_faction = Faction.of(source)
	collision_layer = 0
	_channel = _channel_now()
	collision_mask = ChannelMasks.mask_for_channel(_channel)

func _ready() -> void:
	add_to_group("projectiles")
	_update_visuals()

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	# Capture the base path on the first frame: the spawner sets our
	# global_position AFTER add_child (i.e. after _ready), so we can't read the
	# real origin any earlier.
	if not _started:
		_base_position = global_position
		_started = true
	_tail_time += delta
	var step := _speed * delta
	_distance += step
	_base_position += _direction * step
	_height = _height_at(_distance)

	# Lateral sine weave (perpendicular to travel), if any.
	var lateral := 0.0
	if _attack.lateral_motion == AttackDef.LateralMotion.SINE and _attack.sine_wavelength_px > 0.0:
		lateral = sin(_distance / _attack.sine_wavelength_px * TAU) * _attack.sine_amplitude_px
	var perp := Vector2(-_direction.y, _direction.x)
	global_position = _base_position + perp * lateral

	# Live channel follows height; only touch the mask when it actually changes.
	var ch := _channel_now()
	if ch != _channel:
		_channel = ch
		collision_mask = ChannelMasks.mask_for_channel(ch)

	_update_visuals()

	if _distance >= _max_range:
		queue_free()
		return

	_resolve_overlaps()

## GROUND shots keep their fixed channel; arcs derive it from current height.
func _channel_now() -> AttackDef.Channel:
	if _attack.height_profile == AttackDef.HeightProfile.GROUND:
		return _attack.channel
	return ChannelMasks.channel_for_height(_height)

func _height_at(dist: float) -> float:
	if _attack.height_profile == AttackDef.HeightProfile.GROUND:
		return 0.0
	# LOB / LOB_BOUNCE (bounce not yet modeled): a single arch, 0 at both ends,
	# peaking mid-flight — so it's low at launch, high over the middle (clears
	# low walls), and low again as it lands to strike ground targets.
	var t := clampf(dist / maxf(_max_range, 0.001), 0.0, 1.0)
	return _attack.lob_peak_height * sin(PI * t)

func _resolve_overlaps() -> void:
	for area in get_overlapping_areas():
		if _is_ignored(area):
			continue
		var target: Object = _resolve_hurt_target(area)
		if target != null:
			# Same-side hurtbox: pass straight through it and keep flying. This is
			# NOT an impact — an enemy must not have its own shot eaten by the
			# enemy beside it. Walls below stay faction-blind: they stop everyone.
			if Faction.is_friendly(_source_faction, Faction.of(target)):
				continue
			target.receive_hit(_damage)
			_impact(area.global_position)
			return
		# A blocker on our channel.
		if _attack.wall_behavior == AttackDef.WallBehavior.REFLECT:
			# Scaffold only (Scum's packet does true surface reflection): flip.
			_direction = -_direction
			return
		_impact(global_position)
		return

func _impact(at: Vector2) -> void:
	if _attack.on_hit_effect != null:
		var fx := _attack.on_hit_effect.instantiate()
		get_tree().current_scene.add_child(fx)
		if fx is Node2D:
			(fx as Node2D).global_position = at
	_consumed = true
	queue_free()

func _is_ignored(area: Area2D) -> bool:
	if _ignore == null:
		return false
	return area == _ignore or _ignore.is_ancestor_of(area)

## receive_hit may sit on the Area2D or on the entity that owns it.
func _resolve_hurt_target(area: Area2D) -> Object:
	if area.has_method("receive_hit"):
		return area
	if area.owner != null and area.owner.has_method("receive_hit"):
		return area.owner
	var parent: Node = area.get_parent()
	if parent != null and parent.has_method("receive_hit"):
		return parent
	return null

func _update_visuals() -> void:
	if _visual != null:
		_visual.position = Vector2(0, -_height)
		_visual.scale = Vector2.ONE * (1.0 + _height * CombatTuning.height_scale_per_unit)
	if _tail != null:
		# The trail art is drawn as a horizontal streak (authored along +X), so it
		# has to be turned to face the way we travel or it reads sideways on any
		# non-horizontal shot. The frames are left-right symmetric, so the plain
		# travel angle is enough - no need to flip for leftward/upward shots.
		_tail.position = -_direction * CombatTuning.tail_gap_px
		_tail.rotation = _direction.angle()
		if _tail.vframes > 1:
			_tail.frame = int(_tail_time * CombatTuning.tail_fps) % _tail.vframes
	queue_redraw()

## The ground shadow: an oval (squashed circle) under the projectile, shrinking
## and fading as it climbs. Drawn on the root (ground) node so it stays put while
## the sprite lifts away from it.
func _draw() -> void:
	var shrink := 1.0 / (1.0 + _height * CombatTuning.shadow_shrink_per_unit)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, CombatTuning.shadow_base_radius * shrink, Color(0, 0, 0, CombatTuning.shadow_alpha * shrink))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
