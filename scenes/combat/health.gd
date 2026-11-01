class_name Health
extends Node
## Health — the shared half-heart pool, used by the player and every enemy.
##
## A plain Node (no position, no visuals) parented under whatever it belongs to.
## Keeping it a separate node rather than fields on each entity means the HUD,
## the debug tray and the downed/mini flow all talk to ONE contract regardless of
## whether they're looking at Johnny or a Bag Guy.
##
## Health is counted in HALF-HEARTS (2 = one heart on the HUD), per
## PROJECT_CONTEXT.md. There is no mid-combat regeneration by design — encounters
## are 30-90s and recovery is structural (rest/shop nodes), so `heal()` exists
## for the debug tray and between-encounter flow, not for pickups.

## Fired on every change, including heals and resets — the HUD listens to this.
signal changed(current_half_hearts: int, max_half_hearts: int)
## Fired only when damage actually landed (not when blocked by invulnerability).
signal damaged(amount_half_hearts: int)
## Fired once, when the pool reaches zero.
signal died

@export var max_half_hearts: int = 4:
	set(value):
		max_half_hearts = maxi(1, value)
		_current = mini(_current, max_half_hearts)
		changed.emit(_current, max_half_hearts)

## Blocks all incoming damage. The debug tray's invincibility toggle flips this;
## the player also raises it briefly after a hit (see player.gd i-frames).
@export var invulnerable: bool = false

var _current: int = -1
var _is_dead := false

func _ready() -> void:
	if _current < 0:
		_current = max_half_hearts
	changed.emit(_current, max_half_hearts)

func current() -> int:
	return _current

func is_dead() -> bool:
	return _is_dead

## Apply damage. Returns true if it actually landed, so callers can decide
## whether to play a hit reaction.
func take_damage(amount_half_hearts: int) -> bool:
	if _is_dead or invulnerable or amount_half_hearts <= 0:
		return false
	_current = maxi(0, _current - amount_half_hearts)
	damaged.emit(amount_half_hearts)
	changed.emit(_current, max_half_hearts)
	if _current == 0:
		_is_dead = true
		died.emit()
	return true

func heal(amount_half_hearts: int) -> void:
	if _is_dead or amount_half_hearts <= 0:
		return
	_current = mini(max_half_hearts, _current + amount_half_hearts)
	changed.emit(_current, max_half_hearts)

## Set the pool to an exact value (clamped to 0..max) - used when a character is
## deployed carrying the health they had left from an earlier encounter. Unlike
## `take_damage` it never emits `damaged` or `died`.
func set_current(half_hearts: int) -> void:
	_current = clampi(half_hearts, 0, max_half_hearts)
	_is_dead = _current == 0
	changed.emit(_current, max_half_hearts)

## Full restore, including undoing death — used by the debug tray's reset and by
## a character being brought back between encounters.
func reset_full() -> void:
	_is_dead = false
	_current = max_half_hearts
	changed.emit(_current, max_half_hearts)
