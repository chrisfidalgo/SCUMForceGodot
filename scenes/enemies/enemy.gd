class_name Enemy
extends CharacterBody2D
## enemy.gd — one scene, three behaviours (05-ENEMY-MODEL.md).
##
## Like the player, this is DATA-driven: `archetype` is an Inspector dropdown, so
## a Wanderer and a Seeker are the same scene with a different value, not two
## scripts. That mirrors how TargetDummy handles `elevation`, and it keeps the
## debug tray's spawn buttons trivial.
##
## Deliberately simple: no pathfinding, no navmesh, no behaviour tree, no state
## machine framework. Each archetype is a handful of lines in _physics_process.
## Gain Ground gets its depth from placement and channels, not from clever AI —
## if these ever need more, that is a finding worth having, not a default.
##
## Attacks go through the SAME pipeline as the player's: this node emits
## `attack_fired` and the gym's AttackSpawner builds the projectile. So enemy
## attacks are .tres files tuned in the Inspector, and enemy shots obey the
## channel rules — which is what makes a low wall into real cover.

## Same contract as Player.attack_fired, so one spawner serves both.
signal attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2)
signal died(at_position: Vector2)

## WANDERER — moves aimlessly, never attacks; a body in the way.
## TURRET   — never moves, fires along its authored facing on a cooldown.
## SEEKER   — closes to preferred range, then holds and fires.
enum Archetype { WANDERER, TURRET, SEEKER }

## Which hurt layer(s) this enemy occupies — the same elevation model as the
## target dummies. GROUND is only reachable by LOW attacks, ELEVATED only by
## HIGH, TALL by both. Purely a layer flip; no behaviour changes with it.
enum Elevation { GROUND, ELEVATED, TALL }

const HURT_LOW_BIT := 4
const HURT_HIGH_BIT := 5

@export var archetype: Archetype = Archetype.WANDERER:
	set(value):
		archetype = value
		if is_inside_tree():
			_apply_archetype_look()

@export var elevation: Elevation = Elevation.GROUND:
	set(value):
		elevation = value
		if is_inside_tree():
			_apply_elevation()

@export_group("Health & contact")
@export var max_half_hearts: int = 2
## Damage dealt by walking into the player. Applies to every archetype — even a
## Turret hurts if you stand on it.
@export var contact_damage_half_hearts: int = 1
## Minimum gap between contact hits on the same target, so touching an enemy is
## a series of discrete hits rather than a continuous drain.
@export var contact_cooldown_sec: float = 0.5

@export_group("Movement")
@export var move_speed: float = 40.0
## WANDERER only: how often it picks a new random direction.
@export var wander_change_sec: float = 1.5

@export_group("Attack (TURRET / SEEKER)")
@export var attack: AttackDef
@export var fire_cooldown_sec: float = 1.8
## TURRET only: the direction it fires, in degrees (0 = right, 90 = down).
## Deliberately fixed rather than tracking the player — a turret you can walk
## around is a spatial puzzle; one that tracks you is just pressure.
@export_range(0.0, 360.0, 15.0) var turret_facing_degrees: float = 90.0
## SEEKER only: the distance it tries to hold. Closer than 75% of this and it
## backs away; further and it closes; inside the band it stands and fires.
@export var preferred_range_px: float = 120.0

var faction: int = Faction.Team.ENEMY

var _fire_timer := 0.0
var _wander_timer := 0.0
var _wander_dir := Vector2.RIGHT
var _contact_timers: Dictionary = {}

## Active slow sources -> their multiplier. Held as a set rather than a timer so
## that overlapping fields behave sensibly (the strongest wins, and leaving a
## field restores speed immediately) instead of fighting over one countdown.
var _slow_sources: Dictionary = {}
## Combined slow, 1.0 = unslowed. Read by the movement code each frame.
var speed_multiplier: float = 1.0

@onready var health: Health = $Health
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _contact_box: Area2D = $ContactBox
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("tunable")
	health.max_half_hearts = max_half_hearts
	health.reset_full()
	health.died.connect(_on_died)
	health.damaged.connect(func(_a): _flash())
	_apply_elevation()
	_apply_archetype_look()
	_pick_wander_direction()


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	_tick_contact_timers(delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	match archetype:
		Archetype.WANDERER:
			_process_wanderer(delta)
		Archetype.TURRET:
			_process_turret()
		Archetype.SEEKER:
			_process_seeker()
	_apply_contact_damage()


# --- Behaviours ---------------------------------------------------------------

## Walk a random direction for a while, pick another, reverse off walls.
func _process_wanderer(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
	velocity = _wander_dir * move_speed * speed_multiplier
	move_and_slide()
	if get_slide_collision_count() > 0:
		_wander_dir = -_wander_dir
		_wander_timer = wander_change_sec


## Stand still, fire along the authored facing.
func _process_turret() -> void:
	velocity = Vector2.ZERO
	_try_fire(Vector2.from_angle(deg_to_rad(turret_facing_degrees)))


## Close to preferred range, back off if too close, hold and fire in the band.
func _process_seeker() -> void:
	var player := _find_player()
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()
	if distance > preferred_range_px:
		velocity = direction * move_speed * speed_multiplier
	elif distance < preferred_range_px * 0.75:
		velocity = -direction * move_speed * speed_multiplier
	else:
		velocity = Vector2.ZERO
		_try_fire(direction)
	move_and_slide()


func _pick_wander_direction() -> void:
	_wander_dir = Vector2.from_angle(randf() * TAU)
	_wander_timer = wander_change_sec


func _try_fire(direction: Vector2) -> void:
	if attack == null or _fire_timer > 0.0 or direction == Vector2.ZERO:
		return
	_fire_timer = fire_cooldown_sec
	attack_fired.emit(attack, global_position + direction * 10.0, direction.normalized())


# --- Damage in and out ---------------------------------------------------------

## Same hurtbox contract as the player and the dummies.
func receive_hit(damage_half_hearts: int) -> void:
	health.take_damage(damage_half_hearts)


## Body contact hurts, with a per-target cooldown so overlapping is a series of
## discrete hits rather than a continuous drain.
func _apply_contact_damage() -> void:
	for body in _contact_box.get_overlapping_bodies():
		if not body.has_method("receive_hit"):
			continue
		if Faction.is_friendly(faction, Faction.of(body)):
			continue
		if _contact_timers.get(body, 0.0) > 0.0:
			continue
		_contact_timers[body] = contact_cooldown_sec
		body.receive_hit(contact_damage_half_hearts)


func _tick_contact_timers(delta: float) -> void:
	for key in _contact_timers.keys():
		var remaining: float = _contact_timers[key] - delta
		if remaining <= 0.0 or not is_instance_valid(key):
			_contact_timers.erase(key)
		else:
			_contact_timers[key] = remaining


## --- Being slowed (Curt's bleu cheese) --------------------------------------
## A field calls add_slow when this enemy walks in and remove_slow on the way
## out or when the field expires. Keyed by the source so two fields cannot
## corrupt each other's bookkeeping.
func add_slow(source: Object, multiplier: float) -> void:
	_slow_sources[source] = clampf(multiplier, 0.05, 1.0)
	_recompute_slow()


func remove_slow(source: Object) -> void:
	_slow_sources.erase(source)
	_recompute_slow()


func _recompute_slow() -> void:
	var slowest := 1.0
	for key in _slow_sources.keys():
		if is_instance_valid(key):
			slowest = minf(slowest, _slow_sources[key])
		else:
			_slow_sources.erase(key)
	speed_multiplier = slowest
	# Tint the whole node (not _visual.color, which the hit flash owns) so being
	# slowed is legible without the field itself having to be under the enemy.
	modulate = Color(0.65, 0.85, 1.0) if slowest < 1.0 else Color(1, 1, 1)


func _on_died() -> void:
	died.emit(global_position)
	queue_free()


func _flash() -> void:
	var base := _visual.color
	_visual.color = Color(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_visual, "color", base, 0.12)


# --- Presentation --------------------------------------------------------------

func _apply_elevation() -> void:
	match elevation:
		Elevation.GROUND:
			_hurtbox.collision_layer = 1 << (HURT_LOW_BIT - 1)
		Elevation.ELEVATED:
			_hurtbox.collision_layer = 1 << (HURT_HIGH_BIT - 1)
		Elevation.TALL:
			_hurtbox.collision_layer = (1 << (HURT_LOW_BIT - 1)) | (1 << (HURT_HIGH_BIT - 1))


## Placeholder colour-coding so archetypes are tellable apart at a glance.
func _apply_archetype_look() -> void:
	match archetype:
		Archetype.WANDERER:
			_visual.color = Color(0.85, 0.7, 0.3)
		Archetype.TURRET:
			_visual.color = Color(0.8, 0.3, 0.3)
		Archetype.SEEKER:
			_visual.color = Color(0.85, 0.45, 0.15)


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# --- Live tuning (docs/systems/tuning-panel.md) --------------------------------

func get_tuning_label() -> String:
	return "%s (%s)" % [Archetype.keys()[archetype], Elevation.keys()[elevation]]


func get_tuning_attacks() -> Array:
	return [attack] if attack != null else []


func get_tuning_spec() -> Array:
	var spec: Array = [
		{"property": "move_speed", "min": 0.0, "max": 200.0, "step": 5.0},
		{"property": "contact_damage_half_hearts", "min": 0.0, "max": 4.0, "step": 1.0},
	]
	if archetype == Archetype.WANDERER:
		spec.append({"property": "wander_change_sec", "min": 0.2, "max": 5.0, "step": 0.1})
	else:
		spec.append({"property": "fire_cooldown_sec", "min": 0.2, "max": 5.0, "step": 0.1})
	if archetype == Archetype.TURRET:
		spec.append({"property": "turret_facing_degrees", "min": 0.0, "max": 360.0, "step": 15.0})
	if archetype == Archetype.SEEKER:
		spec.append({"property": "preferred_range_px", "min": 20.0, "max": 300.0, "step": 5.0})
	return spec
