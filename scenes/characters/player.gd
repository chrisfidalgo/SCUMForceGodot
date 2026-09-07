class_name Player
extends CharacterBody2D
## player.gd — generic, data-driven, 8-way-gated player controller.
##
## A CharacterBody2D is a body you move yourself in script (move_and_slide())
## that still collides with solid geometry. One instance plays any character:
## speed, health and the attack kit all come from the assigned CharacterDef
## resource (resources/characters/*.tres), never from bespoke code.
##
## Controls are ARCADE 8-WAY (04-COMBAT-MODEL.md §1): movement snaps to the 8
## compass directions, and FACING is simply the last direction you moved (there
## is no mouse cursor). Both attacks fire straight along that facing. Analog
## stick input is snapped to the same 8 gates, so keyboard and controller feel
## identical. This controller does not spawn projectiles — it emits attack_fired
## and the AttackSpawner (a decoupled listener) does the rest.

## Emitted on a successful attack (input pressed + that attack's cooldown ready).
## `origin` is the muzzle, `aim_direction` is the 8-gated facing. Fixed contract
## with the AttackSpawner — don't change the names/types.
signal attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2)

@export var character_def: CharacterDef = preload("res://resources/characters/johnny.tres")
## How far in front of the player (along facing) attacks spawn. Placeholder.
@export var muzzle_offset_px: float = 10.0

## The 8-gated forward vector: last direction moved, retained while idle.
## Characters start facing North (up).
var facing: Vector2 = Vector2.UP

var _primary_cooldown := 0.0
var _secondary_cooldown := 0.0

@onready var _facing_indicator: Line2D = $FacingIndicator

func _ready() -> void:
	add_to_group("player")
	set_character(character_def)
	_update_facing_indicator()

func _physics_process(delta: float) -> void:
	_process_movement()
	_process_cooldowns(delta)
	_process_attack_input()

func _process_movement() -> void:
	var raw := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var dir := snap_to_8(raw)
	if dir != Vector2.ZERO:
		facing = dir
		_update_facing_indicator()
	var speed: float = character_def.move_speed if character_def else 0.0
	velocity = dir * speed
	move_and_slide()

## Snap an arbitrary input vector to the nearest of the 8 compass directions,
## or Vector2.ZERO if there's no meaningful input. Keyboard already lands on the
## gates; this is what makes an analog stick feel like an 8-way arcade stick.
static func snap_to_8(v: Vector2) -> Vector2:
	if v.length() < 0.2:
		return Vector2.ZERO
	var step := PI / 4.0
	return Vector2.from_angle(roundf(v.angle() / step) * step)

func _process_cooldowns(delta: float) -> void:
	_primary_cooldown = maxf(0.0, _primary_cooldown - delta)
	_secondary_cooldown = maxf(0.0, _secondary_cooldown - delta)

func _process_attack_input() -> void:
	if character_def == null:
		return
	if _primary_cooldown <= 0.0 and Input.is_action_pressed("attack_primary"):
		_fire(character_def.primary_attack, true)
	if _secondary_cooldown <= 0.0 and Input.is_action_pressed("attack_secondary"):
		_fire(character_def.secondary_attack, false)

func _fire(attack: AttackDef, is_primary: bool) -> void:
	if attack == null:
		return
	var origin := global_position + facing * muzzle_offset_px
	if is_primary:
		_primary_cooldown = attack.cooldown_sec
	else:
		_secondary_cooldown = attack.cooldown_sec
	attack_fired.emit(attack, origin, facing)

func _update_facing_indicator() -> void:
	if _facing_indicator != null:
		_facing_indicator.points = PackedVector2Array([Vector2.ZERO, facing * 16.0])

## Runtime character swap (debug tray / rescue flow). Resets cooldowns so the
## newly active character can fire immediately.
func set_character(def: CharacterDef) -> void:
	character_def = def
	_primary_cooldown = 0.0
	_secondary_cooldown = 0.0
