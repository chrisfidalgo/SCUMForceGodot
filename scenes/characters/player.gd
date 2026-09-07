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

## Emitted when this character's health hits zero. The gym (not the player)
## decides what that means — in the gym it spawns a rescuable mini and offers a
## character swap. Keeping the consequence out of here means Phase 2 can react
## differently without touching the controller.
signal went_down(character: CharacterDef, at_position: Vector2)

## Emitted whenever damage lands, so the HUD can flash without polling.
signal health_changed(current_half_hearts: int, max_half_hearts: int)

@export var character_def: CharacterDef = preload("res://resources/characters/johnny.tres")
## How far in front of the player (along facing) attacks spawn. Placeholder.
@export var muzzle_offset_px: float = 10.0
## How long the character is immune after taking a hit. Without this, standing in
## a projectile stream drains a 4-half-heart character in a fraction of a second
## and nothing reads as a discrete "hit". Placeholder — tune by feel.
@export var invuln_after_hit_sec: float = 0.6
## Flash the body this colour while the i-frames run, so being hit is legible.
@export var invuln_flash_color: Color = Color(1.0, 0.4, 0.4, 1.0)

## The 8-gated forward vector: last direction moved, retained while idle.
## Characters start facing North (up).
var facing: Vector2 = Vector2.UP

var _primary_cooldown := 0.0
var _secondary_cooldown := 0.0
var _invuln_timer := 0.0

## Which side this unit is on — read by Projectile so the player's own shots
## can't hurt them and enemy shots can. See scenes/combat/faction.gd.
var faction: int = Faction.Team.PLAYER

## Multiplied into move speed. The escort loop drops this below 1.0 when
## dragging 2+ minis (03-GYM-SPEC.md §4); nothing else should touch it.
var speed_multiplier: float = 1.0

@onready var _facing_indicator: Line2D = $FacingIndicator
@onready var _body_visual: Polygon2D = $BodyVisual
@onready var health: Health = $Health

var _base_color := Color(0.3, 0.55, 0.9, 1.0)

func _ready() -> void:
	add_to_group("player")
	health.damaged.connect(_on_damaged)
	health.changed.connect(func(c, m): health_changed.emit(c, m))
	health.died.connect(_on_died)
	set_character(character_def)
	_update_facing_indicator()

func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	_process_movement()
	_process_cooldowns(delta)
	_process_attack_input()
	_process_invulnerability(delta)

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
	velocity = dir * speed * speed_multiplier
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

## Repaint the body in the new character's placeholder colour, and remember it
## as the colour the i-frame blink returns to.
func _apply_placeholder_look(def: CharacterDef) -> void:
	if _body_visual == null:
		return
	_base_color = def.placeholder_color
	_body_visual.color = _base_color


func _update_facing_indicator() -> void:
	if _facing_indicator != null:
		_facing_indicator.points = PackedVector2Array([Vector2.ZERO, facing * 16.0])

## Fraction of the primary/secondary cooldown still to run: 1.0 just after
## firing, 0.0 when ready. The HUD draws these as bars.
func primary_cooldown_ratio() -> float:
	var total: float = character_def.primary_attack.cooldown_sec if (character_def and character_def.primary_attack) else 0.0
	return 0.0 if total <= 0.0 else clampf(_primary_cooldown / total, 0.0, 1.0)


func secondary_cooldown_ratio() -> float:
	var total: float = character_def.secondary_attack.cooldown_sec if (character_def and character_def.secondary_attack) else 0.0
	return 0.0 if total <= 0.0 else clampf(_secondary_cooldown / total, 0.0, 1.0)


## The hurtbox contract every projectile calls on overlap — same name and
## signature as TargetDummy, so a projectile never needs to know what it hit.
func receive_hit(damage_half_hearts: int) -> void:
	health.take_damage(damage_half_hearts)

func _on_damaged(_amount: int) -> void:
	_invuln_timer = invuln_after_hit_sec
	health.invulnerable = true

func _process_invulnerability(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return
	_invuln_timer -= delta
	# Blink while immune: visible feedback that further hits won't land.
	_body_visual.color = invuln_flash_color if int(_invuln_timer * 20.0) % 2 == 0 else _base_color
	if _invuln_timer <= 0.0:
		health.invulnerable = false
		_body_visual.color = _base_color

func _on_died() -> void:
	velocity = Vector2.ZERO
	_body_visual.color = _base_color
	went_down.emit(character_def, global_position)

## Runtime character swap (debug tray / rescue flow). Resets cooldowns and
## restores the pool to the NEW character's maximum, so swapping to Curt gives
## you Curt's 4 hearts rather than whatever Johnny had left.
func set_character(def: CharacterDef) -> void:
	character_def = def
	_primary_cooldown = 0.0
	_secondary_cooldown = 0.0
	_invuln_timer = 0.0
	if def != null:
		health.max_half_hearts = def.max_half_hearts
		_apply_placeholder_look(def)
	health.reset_full()
	health.invulnerable = false
	speed_multiplier = 1.0
