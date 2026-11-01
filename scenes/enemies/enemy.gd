class_name Enemy
extends CharacterBody2D
## enemy.gd — one scene, any behaviour (06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md §2).
##
## Like the player, this is DATA-driven: `def` is an EnemyDef `.tres` that picks
## three independent things — when the enemy wakes (activation), how it moves
## (idle and active movement), and how it attacks (none / melee / ranged) — plus
## all the numbers. A Wanderer and a Brawler are the same scene with a different
## `def`, not two scripts. What differs per PLACEMENT (elevation, facing, which
## patrol route) lives on this node instead, so ten Turrets can share one file.
##
## Deliberately simple: no pathfinding, no navmesh, no behaviour tree, no state
## machine framework. Distance checks only (no line of sight).
##
## Attacks go through the SAME pipeline as the player's: this node emits
## `attack_fired` and the level's AttackSpawner builds the projectile. So enemy
## attacks are .tres files tuned in the Inspector, and enemy shots obey the
## channel rules — which is what makes a low wall into real cover.

## Same contract as Player.attack_fired, so one spawner serves both.
signal attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2)
signal died(at_position: Vector2)

## Which hurt layer(s) this enemy occupies — the same elevation model as the
## target dummies. GROUND is only reachable by LOW attacks, ELEVATED only by
## HIGH, TALL by both. Purely a layer flip; no behaviour changes with it.
enum Elevation { GROUND, ELEVATED, TALL }

const HURT_LOW_BIT := 4
const HURT_HIGH_BIT := 5

## The enemy type. Spawners set this BEFORE add_child; it is applied in _ready.
@export var def: EnemyDef:
	set(value):
		def = value
		if is_inside_tree():
			_apply_def()

@export var elevation: Elevation = Elevation.GROUND:
	set(value):
		elevation = value
		if is_inside_tree():
			_apply_elevation()

## Direction used by FIXED_FACING attacks, in degrees (0 = right, 90 = down).
## Deliberately fixed rather than tracking the player — a turret you can walk
## around is a spatial puzzle; one that tracks you is just pressure.
@export_range(0.0, 360.0, 15.0) var facing_degrees: float = 90.0

## Any Node2D. Its Marker2D children, in tree order, are the waypoints (global
## coordinates). Only used when the def's idle or active movement is PATROL.
@export var patrol_route: Node2D:
	set(value):
		patrol_route = value
		_waypoints_dirty = true

@export_group("Presentation")
## Body tint while dormant (applied via self_modulate, so it never fights the
## slow tint on `modulate` or the hit flash on the body colour).
@export var dormant_tint: Color = Color(0.45, 0.45, 0.55, 0.8)
## How long the "!" shows after waking.
@export var wake_flash_sec: float = 0.6
## Colour of the wind-up warning ring and aim line.
@export var windup_tell_color: Color = Color(1.0, 0.95, 0.3)
## Length of the aim line shown during a wind-up.
@export var windup_aim_line_px: float = 26.0
## Radius of the wind-up warning ring.
@export var windup_ring_radius_px: float = 11.0
## Pulses per second of the ring.
@export var windup_pulse_hz: float = 8.0

var faction: int = Faction.Team.ENEMY

var _active := true
var _grace_left := 0.0
var _fire_timer := 0.0
var _windup_left := 0.0
var _winding := false
var _windup_dir := Vector2.DOWN
var _wander_timer := 0.0
var _wander_dir := Vector2.RIGHT
var _contact_timers: Dictionary = {}

var _waypoints: Array[Vector2] = []
var _waypoints_dirty := true
var _wp_index := 0
var _wp_step := 1
var _wp_wait := 0.0
var _warned_route := false

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

var _state_label: Label
var _tell_ring: Polygon2D
var _tell_line: Line2D
var _wake_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("tunable")
	_build_tells()
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	_apply_elevation()
	_apply_def()
	_pick_wander_direction()


## Everything that depends on the def. Safe to call again if `def` is swapped.
func _apply_def() -> void:
	if def == null:
		push_warning("Enemy %s has no EnemyDef; using bare defaults." % name)
		def = EnemyDef.new()  # the setter re-enters _apply_def with a def in place
		return
	health.max_half_hearts = def.max_half_hearts
	health.reset_full()
	_visual.color = def.placeholder_color
	_active = def.activation == EnemyDef.Activation.ALWAYS
	_waypoints_dirty = true
	_refresh_state_look(false)
	if _uses_movement(EnemyDef.Movement.PATROL):
		_refresh_waypoints()


func _physics_process(delta: float) -> void:
	if health.is_dead() or def == null:
		return
	_tick_contact_timers(delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_grace_left = maxf(0.0, _grace_left - delta)
	var player := _find_player()
	_update_activation(player)

	if _winding:
		velocity = Vector2.ZERO
		_tick_windup(delta)
	else:
		_move(delta, player)
		_try_attack(player)
	_update_tells()
	_apply_contact_damage()


# --- Activation ----------------------------------------------------------------

func _update_activation(player: Node2D) -> void:
	if def.activation == EnemyDef.Activation.ALWAYS or player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	if not _active:
		if distance <= def.activation_range_px:
			_wake()
	elif def.leash_enabled and _grace_left <= 0.0 and distance > def.leash_range_px:
		_sleep()


func _wake() -> void:
	if _active:
		return
	_active = true
	_grace_left = def.leash_grace_sec
	_refresh_state_look(true)


func _sleep() -> void:
	_active = false
	_winding = false
	_nearest_waypoint()
	_refresh_state_look(false)


func is_active() -> bool:
	return _active


# --- Movement ------------------------------------------------------------------

func _current_movement() -> EnemyDef.Movement:
	return def.active_movement if _active else def.idle_movement


func _uses_movement(kind: EnemyDef.Movement) -> bool:
	if def.activation == EnemyDef.Activation.ALWAYS:
		return def.active_movement == kind
	return def.idle_movement == kind or def.active_movement == kind


func _move(delta: float, player: Node2D) -> void:
	match _current_movement():
		EnemyDef.Movement.STATIONARY:
			velocity = Vector2.ZERO
		EnemyDef.Movement.WANDER:
			_move_wander(delta)
		EnemyDef.Movement.PATROL:
			_move_patrol(delta)
		EnemyDef.Movement.SEEK:
			_move_seek(player)


## Walk a random direction for a while, pick another, reverse off walls.
func _move_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
	velocity = _wander_dir * def.move_speed * speed_multiplier
	move_and_slide()
	if get_slide_collision_count() > 0:
		_wander_dir = -_wander_dir
		_wander_timer = def.wander_change_sec


## Close to preferred range, back off if too close, hold in the band.
func _move_seek(player: Node2D) -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()
	if distance > def.preferred_range_px:
		velocity = direction * def.move_speed * speed_multiplier
	elif def.retreat_ratio > 0.0 and distance < def.preferred_range_px * def.retreat_ratio:
		velocity = -direction * def.move_speed * speed_multiplier
	else:
		velocity = Vector2.ZERO
	if velocity != Vector2.ZERO:
		move_and_slide()


## Walk the route, pausing at each point. No route = stand still (warned once).
func _move_patrol(delta: float) -> void:
	_refresh_waypoints()
	if _waypoints.is_empty():
		velocity = Vector2.ZERO
		if not _warned_route:
			_warned_route = true
			push_warning("Enemy %s patrols but has no patrol_route with Marker2D children; standing still." % name)
		return
	if _wp_wait > 0.0:
		_wp_wait -= delta
		velocity = Vector2.ZERO
		return
	_wp_index = clampi(_wp_index, 0, _waypoints.size() - 1)
	var to_point := _waypoints[_wp_index] - global_position
	if to_point.length() <= def.waypoint_reach_px:
		_advance_waypoint()
		_wp_wait = def.patrol_wait_sec
		velocity = Vector2.ZERO
		return
	velocity = to_point.normalized() * def.move_speed * speed_multiplier
	move_and_slide()


func _advance_waypoint() -> void:
	var count := _waypoints.size()
	if count <= 1:
		return
	if def.patrol_mode == EnemyDef.PatrolMode.LOOP:
		_wp_index = (_wp_index + 1) % count
	else:
		if _wp_index + _wp_step >= count or _wp_index + _wp_step < 0:
			_wp_step = -_wp_step
		_wp_index += _wp_step


func _refresh_waypoints() -> void:
	if not _waypoints_dirty:
		return
	_waypoints_dirty = false
	_waypoints.clear()
	if patrol_route != null and is_instance_valid(patrol_route):
		for child in patrol_route.get_children():
			if child is Marker2D:
				_waypoints.append((child as Marker2D).global_position)
	_wp_index = 0
	_wp_step = 1


## After giving up a chase, resume the route from the closest point on it.
func _nearest_waypoint() -> void:
	_refresh_waypoints()
	var best := INF
	for i in _waypoints.size():
		var d := global_position.distance_to(_waypoints[i])
		if d < best:
			best = d
			_wp_index = i


func _pick_wander_direction() -> void:
	_wander_dir = Vector2.from_angle(randf() * TAU)
	_wander_timer = def.wander_change_sec if def != null else 1.5


# --- Attacking -----------------------------------------------------------------

func _try_attack(player: Node2D) -> void:
	if not _active or def.attack_style == EnemyDef.AttackStyle.NONE:
		return
	if def.attack == null or _fire_timer > 0.0:
		return
	if velocity != Vector2.ZERO and not def.fire_while_moving:
		return
	var direction := _aim_direction(player)
	if direction == Vector2.ZERO:
		return
	if not _in_attack_range(player):
		return
	if def.windup_sec > 0.0:
		_winding = true
		_windup_left = def.windup_sec
		_windup_dir = direction  # locked now, so the player can sidestep
		velocity = Vector2.ZERO
	else:
		_fire(direction)


func _aim_direction(player: Node2D) -> Vector2:
	if def.aim == EnemyDef.Aim.FIXED_FACING:
		return Vector2.from_angle(deg_to_rad(facing_degrees))
	if player == null:
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()


## MELEE needs the player inside its reach. RANGED needs them inside
## attack_range_px (0 = any distance, and a FIXED_FACING turret then needs no
## player at all, exactly like the old Turret).
func _in_attack_range(player: Node2D) -> bool:
	var unlimited_ranged := def.attack_style == EnemyDef.AttackStyle.RANGED \
			and def.attack_range_px <= 0.0
	if unlimited_ranged:
		return true
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= def.attack_range_px


func _tick_windup(delta: float) -> void:
	_windup_left -= delta
	if _windup_left <= 0.0:
		_winding = false
		_fire(_windup_dir)


func _fire(direction: Vector2) -> void:
	_fire_timer = def.fire_cooldown_sec
	attack_fired.emit(def.attack, global_position + direction * def.muzzle_offset_px, direction.normalized())


# --- Damage in and out ---------------------------------------------------------

## Same hurtbox contract as the player and the dummies.
func receive_hit(damage_half_hearts: int) -> void:
	health.take_damage(damage_half_hearts)


func _on_damaged(_amount: int) -> void:
	_flash()
	if def != null and def.activation == EnemyDef.Activation.PROXIMITY \
			and def.wake_on_damage and not _active:
		_wake()


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
		_contact_timers[body] = def.contact_cooldown_sec
		body.receive_hit(def.contact_damage_half_hearts)


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
	# The dormant look uses _visual.self_modulate so the two never fight.
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


## Build the placeholder legibility nodes: a state label ("z" asleep, "!" on wake)
## and the wind-up ring + aim line. All hidden until needed.
func _build_tells() -> void:
	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 8)
	_state_label.position = Vector2(-5, -24)
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_label.z_index = 5
	add_child(_state_label)

	_tell_ring = Polygon2D.new()
	var ring := PackedVector2Array()
	for i in 12:
		ring.append(Vector2.from_angle(TAU * i / 12.0) * windup_ring_radius_px)
	_tell_ring.polygon = ring
	_tell_ring.color = windup_tell_color
	_tell_ring.z_index = -1
	_tell_ring.visible = false
	add_child(_tell_ring)

	_tell_line = Line2D.new()
	_tell_line.width = 2.0
	_tell_line.default_color = windup_tell_color
	_tell_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	_tell_line.z_index = 4
	_tell_line.visible = false
	add_child(_tell_line)


## Dormant = dimmed body + "z". Waking shows "!" briefly. Active = plain.
func _refresh_state_look(just_woke: bool) -> void:
	if _state_label == null:
		return
	if _wake_tween != null and _wake_tween.is_valid():
		_wake_tween.kill()
	if not _active:
		_visual.self_modulate = dormant_tint
		_state_label.text = "z"
		_state_label.modulate = Color(0.7, 0.8, 1.0)
		_state_label.visible = true
	else:
		_visual.self_modulate = Color(1, 1, 1, 1)
		if just_woke:
			_state_label.text = "!"
			_state_label.modulate = Color(1.0, 0.9, 0.2)
			_state_label.visible = true
			_wake_tween = create_tween()
			_wake_tween.tween_interval(wake_flash_sec)
			_wake_tween.tween_callback(func(): _state_label.visible = false)
		else:
			_state_label.visible = false


func _update_tells() -> void:
	if _winding:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * windup_pulse_hz)
		_tell_ring.visible = true
		_tell_ring.color = Color(windup_tell_color, 0.35 + 0.5 * pulse)
		_tell_line.visible = true
		_tell_line.points = PackedVector2Array([Vector2.ZERO, _windup_dir * windup_aim_line_px])
	else:
		_tell_ring.visible = false
		_tell_line.visible = false


func is_winding_up() -> bool:
	return _winding


## The player, or null when there is nothing to target — including between
## deploys, when the player node still exists but nobody is on the field.
func _find_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.get("on_field"):
		return null
	return player


# --- Live tuning (docs/systems/tuning-panel.md) --------------------------------

func get_tuning_label() -> String:
	var type_name := def.display_name if def != null and def.display_name != "" else "Enemy"
	return "%s (%s)" % [type_name, Elevation.keys()[elevation]]


func get_tuning_attacks() -> Array:
	return [def.attack] if def != null and def.attack != null else []


## Exposes only the def numbers that matter for this def's choices. Paths use
## "def:<field>" so the panel edits the shared resource (every enemy of the type).
func get_tuning_spec() -> Array:
	var spec: Array = []
	if def == null:
		return spec
	var proximity := def.activation == EnemyDef.Activation.PROXIMITY
	var moves := def.active_movement != EnemyDef.Movement.STATIONARY \
			or (proximity and def.idle_movement != EnemyDef.Movement.STATIONARY)
	if moves:
		spec.append({"property": "def:move_speed", "min": 0.0, "max": 200.0, "step": 5.0})
	spec.append({"property": "def:contact_damage_half_hearts", "min": 0.0, "max": 4.0, "step": 1.0})
	if _uses_movement(EnemyDef.Movement.WANDER):
		spec.append({"property": "def:wander_change_sec", "min": 0.2, "max": 5.0, "step": 0.1})
	if _uses_movement(EnemyDef.Movement.PATROL):
		spec.append({"property": "def:patrol_wait_sec", "min": 0.0, "max": 5.0, "step": 0.1})
	if _uses_movement(EnemyDef.Movement.SEEK):
		spec.append({"property": "def:preferred_range_px", "min": 10.0, "max": 300.0, "step": 5.0})
		spec.append({"property": "def:retreat_ratio", "min": 0.0, "max": 1.0, "step": 0.05})
	if def.attack_style != EnemyDef.AttackStyle.NONE:
		spec.append({"property": "def:fire_cooldown_sec", "min": 0.2, "max": 5.0, "step": 0.1})
		spec.append({"property": "def:windup_sec", "min": 0.0, "max": 2.0, "step": 0.05})
		spec.append({"property": "def:attack_range_px", "min": 0.0, "max": 400.0, "step": 5.0})
	if proximity:
		spec.append({"property": "def:activation_range_px", "min": 10.0, "max": 400.0, "step": 5.0})
		if def.leash_enabled:
			spec.append({"property": "def:leash_range_px", "min": 10.0, "max": 600.0, "step": 5.0})
	if def.aim == EnemyDef.Aim.FIXED_FACING and def.attack_style != EnemyDef.AttackStyle.NONE:
		spec.append({"property": "facing_degrees", "min": 0.0, "max": 360.0, "step": 15.0})
	return spec
