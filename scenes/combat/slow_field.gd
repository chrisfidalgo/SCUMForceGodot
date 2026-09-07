class_name SlowField
extends Area2D
## slow_field.gd — a pool of spilled bleu cheese that slows enemies standing in
## it. Curt's mechanical identity (04-COMBAT-MODEL.md §4).
##
## Spawned by a projectile's `on_hit_effect`, at the point the shot ended. Two
## variants exist as scenes, differing only in exported numbers and whether they
## carry a burst animation:
##
##   slow_field_small.tscn — Curt's PRIMARY. Tiny and brief, almost incidental,
##                           and only left where the packet actually hit someone.
##   slow_field_spill.tscn — Curt's SECONDARY. Plays the 9-frame explosion FIRST,
##                           then leaves a standing pool wide enough to hold one
##                           or two enemies. Left wherever the container lands —
##                           enemy, wall or bare floor — which is what makes it
##                           area denial: throw it at a doorway nobody is in.
##
## LIFECYCLE: burst (optional) -> pool appears -> pool fades -> free. Nothing is
## slowed during the burst; the cheese is still in the air.
##
## Slowing is a SET, not a timer: while an enemy overlaps, this field registers
## itself on that enemy as one slow source; leaving restores speed at once, and
## two overlapping pools resolve to the strongest rather than fighting over one
## countdown. Overlaps are polled each physics frame rather than driven by
## body_entered, because the pool grows and bodies would otherwise be missed as
## the shape resizes.
##
## Only affects nodes implementing `add_slow` — enemies. Curt is deliberately
## immune to his own cheese. If an enemy ever needs a slowing attack, give Player
## the same two methods; note Player.speed_multiplier is owned by the escort loop,
## so that wiring needs a moment's thought rather than a copy-paste.
##
## DRAW ORDER: this sits at z_index -1 and the gym floor at -10, so the pool
## renders on the ground but under everything standing on it. A ground effect
## that is not ABOVE the floor node is simply invisible.

## How wide the pool gets (its horizontal radius, in pixels).
@export var radius_px: float = 14.0
## How long the pool lasts, after any burst, before fading out and freeing itself.
@export var duration_sec: float = 0.8
## Move-speed multiplier applied to enemies inside. 0.4 = 40% speed.
@export_range(0.05, 1.0, 0.05) var slow_multiplier: float = 0.5
## Seconds spent expanding to full size once the pool appears.
@export var grow_in_sec: float = 0.0
## Near-white with a cold blue cast, read as a spill lying on the floor the same
## way the projectile's ground shadow does.
@export var color: Color = Color(0.90, 0.94, 1.0, 0.62)
## Frames per second for the burst animation, when a Burst sprite is present.
@export var burst_fps: float = 24.0

var _age := 0.0
var _burst_time := 0.0
var _bursting := false
var _current_radius := 0.0
var _affected: Dictionary = {}

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _burst: Sprite2D = get_node_or_null("Burst")


func _ready() -> void:
	add_to_group("effects")
	# A fresh shape per instance: shapes are resources, so a shared one would
	# mean every pool on the field grew whenever any single pool grew.
	_shape.shape = CircleShape2D.new()
	_bursting = _burst != null and _burst.texture != null
	if _burst != null:
		_burst.visible = _bursting
	# No pool at all until the burst finishes.
	_set_radius(0.0 if (_bursting or grow_in_sec > 0.0) else radius_px)


func _physics_process(delta: float) -> void:
	if _bursting:
		_process_burst(delta)
		return
	_age += delta
	if grow_in_sec > 0.0 and _age < grow_in_sec:
		_set_radius(radius_px * (_age / grow_in_sec))
	elif _current_radius < radius_px:
		_set_radius(radius_px)
	_refresh_affected()
	queue_redraw()
	if _age >= duration_sec:
		_expire()


## Play the explosion sheet once, then hand over to the pool.
func _process_burst(delta: float) -> void:
	_burst_time += delta
	var total: int = maxi(1, _burst.hframes * _burst.vframes)
	var index := int(_burst_time * burst_fps)
	if index >= total:
		_bursting = false
		_burst.visible = false
		return
	_burst.frame = index


## Apply the slow to everything currently inside, and release anything that left.
func _refresh_affected() -> void:
	var inside: Dictionary = {}
	for body in get_overlapping_bodies():
		if not body.has_method("add_slow"):
			continue
		inside[body] = true
		if not _affected.has(body):
			body.add_slow(self, slow_multiplier)
			_affected[body] = true
	for body in _affected.keys():
		if inside.has(body):
			continue
		if is_instance_valid(body):
			body.remove_slow(self)
		_affected.erase(body)


func _expire() -> void:
	for body in _affected.keys():
		if is_instance_valid(body):
			body.remove_slow(self)
	_affected.clear()
	queue_free()


## NOTE: the pool is DRAWN as an oval (squashed vertically like a shadow) but its
## collision is a circle of the full horizontal radius, because Godot 2D has no
## ellipse shape. An enemy slightly above or below the visible oval is therefore
## still caught. That is deliberate generosity — for a slow, forgiving beats
## stingy, and the player judges the area by the oval they can see.
func _set_radius(value: float) -> void:
	_current_radius = value
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = maxf(value, 0.01)


func _draw() -> void:
	if _bursting or _current_radius <= 0.0:
		return
	var life := clampf(_age / maxf(duration_sec, 0.001), 0.0, 1.0)
	# Hold full opacity for most of the life, then fade over the last third, so
	# the pool reads as solid rather than continuously dying.
	var fade := 1.0 - clampf((life - 0.66) / 0.34, 0.0, 1.0)
	var body_color := Color(color.r, color.g, color.b, color.a * fade)
	var rim_color := Color(0.72, 0.80, 0.95, color.a * fade * 0.85)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, _current_radius, body_color)
	draw_circle(Vector2.ZERO, _current_radius, rim_color, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
