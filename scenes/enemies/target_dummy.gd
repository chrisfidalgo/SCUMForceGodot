class_name TargetDummy
extends Node2D
## target_dummy.gd — a stationary hit-test target for the gym; never dies.
##
## `elevation` is an @export enum that decides which "hurt" physics layer(s)
## the dummy's Hurtbox (an Area2D — the node type that reports overlaps
## instead of blocking movement, unlike a StaticBody2D) occupies. Moving a
## unit between GROUND, ELEVATED, and TALL is purely a layer flip, never a
## code branch elsewhere (02-ARCHITECTURE.md §4).
##
## Every dummy exposes receive_hit() — the one method a projectile (built in
## packet P1c) calls on overlap. Keep this name/signature exact so wiring the
## projectile in later is pure plumbing, not a rewrite.

enum Elevation { GROUND, ELEVATED, TALL }

## Bit position (1-indexed, matching Project Settings > Layer Names > 2D
## Physics) of each named layer this dummy cares about. Frozen in Phase 0 —
## see docs/plan/02-ARCHITECTURE.md §4.
const HURT_LOW_BIT: int = 4
const HURT_HIGH_BIT: int = 5

## Which hurt layer(s) this dummy's hurtbox sits on. Change this in the
## Inspector to move the dummy between elevations — no script edit needed.
@export var elevation: Elevation = Elevation.GROUND

@export_group("Hit feedback (placeholder art/tuning)")
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var flash_duration_sec: float = 0.12
@export var damage_number_rise_px: float = 24.0
@export var damage_number_duration_sec: float = 0.6

@onready var _hurtbox: Area2D = $Hurtbox
@onready var _visual: ColorRect = $Visual
@onready var _hit_count_label: Label = $HitCountLabel

var _hit_count: int = 0
var _base_color: Color

## Emitted after every receive_hit() call, in case other systems (HUD, debug
## tray) want to react without polling the counter.
signal hit_received(damage_half_hearts: int)


func _ready() -> void:
	_base_color = _visual.color
	_apply_elevation()
	_refresh_hit_count_label()


## The shared hurtbox contract every projectile calls on overlap.
func receive_hit(damage_half_hearts: int) -> void:
	_hit_count += 1
	_flash()
	_spawn_damage_number(damage_half_hearts)
	_refresh_hit_count_label()
	hit_received.emit(damage_half_hearts)


## Debug reset (wired to the gym's F4 tray button in a later packet).
func reset_counter() -> void:
	_hit_count = 0
	_refresh_hit_count_label()


func _apply_elevation() -> void:
	match elevation:
		Elevation.GROUND:
			_hurtbox.collision_layer = 1 << (HURT_LOW_BIT - 1)
		Elevation.ELEVATED:
			_hurtbox.collision_layer = 1 << (HURT_HIGH_BIT - 1)
		Elevation.TALL:
			_hurtbox.collision_layer = (1 << (HURT_LOW_BIT - 1)) | (1 << (HURT_HIGH_BIT - 1))


func _flash() -> void:
	_visual.color = flash_color
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "color", _base_color, flash_duration_sec)


func _spawn_damage_number(damage_half_hearts: int) -> void:
	var label := Label.new()
	label.text = "-%d" % damage_half_hearts
	label.position = Vector2(-8.0, -26.0)
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - damage_number_rise_px, damage_number_duration_sec)
	tween.tween_property(label, "modulate:a", 0.0, damage_number_duration_sec)
	await tween.finished
	label.queue_free()


func _refresh_hit_count_label() -> void:
	_hit_count_label.text = "%s — Hits: %d" % [Elevation.keys()[elevation], _hit_count]
