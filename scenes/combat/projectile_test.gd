extends Node2D
## projectile_test.gd — standalone proof scene for packet P1c (the attack &
## channel system). Fires the four real AttackDef .tres files at placeholder
## hurtboxes/blockers so the channel x elevation matrix and the
## structure-blocking matrix (03-GYM-SPEC.md §7.4-7.5) can be checked by hand
## without the real player or dummies, which other packets own. Open with F6.
##
## Layout: five parallel lanes run bottom (Origin, y=300) to top (a dummy,
## y=140). The first three lanes are unobstructed (GROUND/ELEVATED/TALL
## dummies only) to show the channel x elevation matrix; the last two put a
## LOW WALL or TALL WALL partway up to show the structure-blocking matrix. A
## sixth cluster to the right tests Rind Slam's self-centered radial burst.
##
## Keys 1-4 (or the on-screen buttons) each fire one attack from every
## relevant origin at once. Watch the "hits: N" counters under each dummy.

const TP_ROLL: AttackDef = preload("res://resources/attacks/tp_roll.tres")
const LONG_TOSS: AttackDef = preload("res://resources/attacks/long_toss.tres")
## Curt's current kit stands in for the retired Cheese Wheel / Rind Slam.
const CHEESE_WHEEL: AttackDef = preload("res://resources/attacks/bleu_cheese_packet.tres")
const RIND_SLAM: AttackDef = preload("res://resources/attacks/bleu_cheese_lob.tres")

@onready var _spawner: AttackSpawner = $AttackSpawner

## Every traveling-attack lane fires straight up (toward the dummy row) from
## its own Origin marker.
@onready var _lane_origins: Array[Marker2D] = [
	$LaneGround/Origin,
	$LaneElevated/Origin,
	$LaneTall/Origin,
	$LaneLowWall/Origin,
	$LaneTallWall/Origin,
]

@onready var _burst_origin: Marker2D = $BurstCluster/Origin

func _ready() -> void:
	$UI/ButtonTPRoll.pressed.connect(_fire_traveling.bind(TP_ROLL))
	$UI/ButtonLongToss.pressed.connect(_fire_traveling.bind(LONG_TOSS))
	$UI/ButtonCheeseWheel.pressed.connect(_fire_traveling.bind(CHEESE_WHEEL))
	$UI/ButtonRindSlam.pressed.connect(_fire_burst.bind(RIND_SLAM))

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_fire_traveling(TP_ROLL)
		KEY_2:
			_fire_traveling(LONG_TOSS)
		KEY_3:
			_fire_traveling(CHEESE_WHEEL)
		KEY_4:
			_fire_burst(RIND_SLAM)

func _fire_traveling(attack: AttackDef) -> void:
	# source = null: this test scene has no firer with its own hurtbox to
	# ignore (the real player, packet P1a, passes itself for that).
	for origin in _lane_origins:
		_spawner.spawn_attack(attack, origin.global_position, Vector2.UP, null)

func _fire_burst(attack: AttackDef) -> void:
	_spawner.spawn_attack(attack, _burst_origin.global_position, Vector2.UP, null)
