class_name Player
extends CharacterBody2D
## player.gd — generic, data-driven player controller (P1a).
##
## A CharacterBody2D is Godot's node for a body you move yourself in script
## (via `move_and_slide()`) that still collides with solid geometry — unlike a
## plain Node2D, walls actually stop it. One instance of this scene plays
## EITHER Johnny or Curt (or any future recruit): everything that makes them
## feel different — speed, health, attacks — comes from the assigned
## `CharacterDef` resource (`resources/characters/*.tres`), never from a
## bespoke script. New character = new .tres, not new code.
##
## This controller does NOT spawn projectiles. On a successful attack input it
## only emits `attack_fired`; packet P1c's projectile spawner (a separate,
## decoupled listener) does the actual spawning. That separation is exactly
## what Godot signals are for: this node doesn't need to know who — if
## anyone — is listening.

## Emitted once per successful attack trigger (input pressed + that attack's
## own cooldown elapsed). `attack` is the AttackDef fired, `origin` is the
## world-space muzzle point, `aim_direction` is the resolved, normalized
## direction after aim-type handling. Exact names/types are a fixed contract
## with packet P1c — do not change them.
signal attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2)

## The active character's data (move speed, health, attack kit). Assign a
## different resources/characters/*.tres in the Inspector to swap kits without
## touching this script — or call set_character() at runtime.
@export var character_def: CharacterDef = preload("res://resources/characters/johnny.tres")

## How far in front of the player (along facing) attacks spawn from. Placeholder.
@export var muzzle_offset_px: float = 12.0

@export_group("Debug")
## Draws a brief line showing the resolved aim direction whenever an attack
## fires. Standalone-testing aid only — see _on_attack_fired_debug_visual().
@export var show_debug_aim_feedback: bool = true
## How long the debug aim-feedback line stays visible after a fire.
@export var debug_fire_flash_seconds: float = 0.15

## Normalized direction from the player to the mouse cursor, recomputed every
## physics frame (02-ARCHITECTURE.md §7). FORWARD_VECTOR attacks fire straight
## along this; FREE_CONE attacks aim toward the cursor but clamped to a cone
## around it; FIXED attacks ignore it entirely.
var facing: Vector2 = Vector2.DOWN

var _primary_cooldown_remaining: float = 0.0
var _secondary_cooldown_remaining: float = 0.0
var _debug_fire_flash_timer: float = 0.0

@onready var _facing_indicator: Line2D = $FacingIndicator
@onready var _debug_fire_flash: Line2D = $DebugFireFlash


func _ready() -> void:
	set_character(character_def)
	_debug_fire_flash.visible = false
	# Debug-only visualization, wired through the signal (not called directly
	# from the fire path below) so the core attack logic stays free of debug
	# concerns. P1c's real projectile spawner will listen to attack_fired the
	# same decoupled way.
	attack_fired.connect(_on_attack_fired_debug_visual)


func _physics_process(delta: float) -> void:
	_process_movement()
	_process_facing()
	_process_cooldowns(delta)
	_process_attack_input()


func _process_movement() -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	var speed: float = character_def.move_speed if character_def else 0.0
	velocity = input_dir * speed
	move_and_slide()


func _process_facing() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.0001:
		facing = to_mouse.normalized()
	_facing_indicator.points = PackedVector2Array([Vector2.ZERO, facing * 16.0])


func _process_cooldowns(delta: float) -> void:
	_primary_cooldown_remaining = maxf(0.0, _primary_cooldown_remaining - delta)
	_secondary_cooldown_remaining = maxf(0.0, _secondary_cooldown_remaining - delta)
	if _debug_fire_flash_timer > 0.0:
		_debug_fire_flash_timer = maxf(0.0, _debug_fire_flash_timer - delta)
		if _debug_fire_flash_timer == 0.0:
			_debug_fire_flash.visible = false


func _process_attack_input() -> void:
	if character_def == null:
		return
	if _primary_cooldown_remaining <= 0.0 and Input.is_action_pressed("attack_primary"):
		_try_fire(character_def.primary_attack, true)
	if _secondary_cooldown_remaining <= 0.0 and Input.is_action_pressed("attack_secondary"):
		_try_fire(character_def.secondary_attack, false)


func _try_fire(attack: AttackDef, is_primary: bool) -> void:
	if attack == null:
		return
	var aim_direction: Vector2 = resolve_aim_direction(attack, facing, get_global_mouse_position() - global_position)
	var origin: Vector2 = global_position + facing * muzzle_offset_px
	if is_primary:
		_primary_cooldown_remaining = attack.cooldown_sec
	else:
		_secondary_cooldown_remaining = attack.cooldown_sec
	attack_fired.emit(attack, origin, aim_direction)


## The three aim-type resolvers in one typed, stateless function: given the
## attack's aim_type plus the current facing and toward-cursor directions,
## return the normalized direction the attack actually travels.
##   FIXED          — ignores the cursor; returns facing (the attack's own
##                     pattern, e.g. a radial burst, doesn't use direction).
##   FORWARD_VECTOR — returns facing.
##   FREE_CONE      — returns the cursor direction clamped to
##                     ±(cone_degrees / 2) around facing.
static func resolve_aim_direction(attack: AttackDef, facing_dir: Vector2, to_cursor: Vector2) -> Vector2:
	if attack.aim_type == AttackDef.AimType.FREE_CONE:
		return _clamp_to_cone(facing_dir, to_cursor, attack.cone_degrees)
	return facing_dir


## Clamps `to_cursor`'s angle to within `cone_degrees` of `facing_dir`'s angle,
## then rebuilds a unit vector at the clamped angle. Pure and typed so it can
## be reasoned about (and tested) independent of the scene tree.
static func _clamp_to_cone(facing_dir: Vector2, to_cursor: Vector2, cone_degrees: float) -> Vector2:
	if to_cursor.length_squared() <= 0.0001:
		return facing_dir
	var facing_angle: float = facing_dir.angle()
	var cursor_angle: float = to_cursor.angle()
	var delta_angle: float = wrapf(cursor_angle - facing_angle, -PI, PI)
	var half_cone: float = deg_to_rad(cone_degrees) * 0.5
	delta_angle = clampf(delta_angle, -half_cone, half_cone)
	return Vector2.from_angle(facing_angle + delta_angle)


## Debug-only: flashes a line from the muzzle showing the resolved aim
## direction out to the attack's range. Purely cosmetic — never read by
## gameplay code. Toggle off via the Debug > Show Debug Aim Feedback export.
func _on_attack_fired_debug_visual(attack: AttackDef, origin: Vector2, aim_direction: Vector2) -> void:
	if not show_debug_aim_feedback:
		return
	var local_origin: Vector2 = to_local(origin)
	_debug_fire_flash.points = PackedVector2Array([local_origin, local_origin + aim_direction * attack.range_px])
	_debug_fire_flash.visible = true
	_debug_fire_flash_timer = debug_fire_flash_seconds


## Runtime character swap: assign a new CharacterDef and reset per-attack
## cooldowns so the newly active character can fire immediately. Used by the
## debug tray's character-swap hotkey and the rescue/roster-swap flow.
func set_character(def: CharacterDef) -> void:
	character_def = def
	_primary_cooldown_remaining = 0.0
	_secondary_cooldown_remaining = 0.0
