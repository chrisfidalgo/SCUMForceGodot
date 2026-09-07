class_name SlowField
extends Area2D
## slow_field.gd — a patch of spilled bleu cheese that slows enemies standing in
## it. Curt's mechanical identity (04-COMBAT-MODEL.md §4).
##
## Spawned by a projectile's `on_hit_effect`, at the point the shot ended. Two
## variants exist as scenes, differing only in exported numbers:
##
##   slow_field_small.tscn — Curt's PRIMARY. Small, brief, and only left behind
##                           where the packet actually hit an enemy.
##   slow_field_spill.tscn — Curt's SECONDARY. Wider, longer, grows in, and left
##                           wherever the container lands — enemy, wall or bare
##                           floor. That last part is what makes it area denial:
##                           you can throw it at a doorway nobody is standing in.
##
## Slowing is a SET, not a timer: while an enemy overlaps, this field is
## registered on it as one slow source; leaving restores speed at once, and two
## overlapping fields resolve to the strongest rather than fighting over one
## countdown. Overlaps are polled each physics frame rather than driven by
## body_entered, because the spill variant grows and bodies would otherwise be
## missed as the shape resizes.
##
## Only affects nodes that implement `add_slow` — enemies. The player is
## deliberately immune to their own cheese; if an enemy ever needs a slowing
## attack, give Player the same two methods and it works with no change here.

## How big the puddle gets, in pixels.
@export var radius_px: float = 14.0
## How long it lasts before fading out and freeing itself.
@export var duration_sec: float = 0.8
## Move-speed multiplier applied to enemies inside. 0.5 = half speed.
@export_range(0.05, 1.0, 0.05) var slow_multiplier: float = 0.5
## Seconds spent expanding to full size. 0 = appears instantly (the packet);
## a small value gives the container spill its splash-outward feel.
@export var grow_in_sec: float = 0.0
## Cream, per the art direction. Alpha fades to nothing over the lifetime.
@export var color: Color = Color(0.96, 0.94, 0.72, 0.55)

var _age := 0.0
var _current_radius := 0.0
var _affected: Dictionary = {}

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("effects")
	# A fresh shape per instance: shapes are resources and would otherwise be
	# shared between every puddle on the field, so one growing would grow all.
	_shape.shape = CircleShape2D.new()
	_set_radius(0.0 if grow_in_sec > 0.0 else radius_px)


func _physics_process(delta: float) -> void:
	_age += delta
	if grow_in_sec > 0.0 and _age < grow_in_sec:
		_set_radius(radius_px * (_age / grow_in_sec))
	elif _current_radius < radius_px:
		_set_radius(radius_px)

	_refresh_affected()
	queue_redraw()

	if _age >= duration_sec:
		_expire()


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


func _set_radius(value: float) -> void:
	_current_radius = value
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = maxf(value, 0.01)


## An oval rather than a circle, squashed the same way the projectile's ground
## shadow is, so it reads as lying ON the floor rather than floating.
func _draw() -> void:
	var life := clampf(_age / maxf(duration_sec, 0.001), 0.0, 1.0)
	var faded := Color(color.r, color.g, color.b, color.a * (1.0 - life))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, _current_radius, faded)
	draw_circle(Vector2.ZERO, _current_radius, Color(color.r * 0.8, color.g * 0.8, 0.45,
		faded.a * 0.9), false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
