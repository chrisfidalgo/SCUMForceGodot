extends Node2D
## gym.gd — the combat-testing arena, and the seam where the three Phase-1
## packets meet (integration pass 1).
##
## The scene assembles the pieces built by the parallel packets:
##   • Player (P1a)        — WASD/mouse controller that emits `attack_fired`.
##   • AttackSpawner (P1c) — turns a fired AttackDef into a projectile/burst.
##   • Structures & dummies (P1b) — the channel/elevation test targets.
##
## The only wiring the arena itself owns is routing the player's fire signal to
## the spawner. Doing it here (rather than the player reaching for the spawner,
## or vice-versa) keeps both packets decoupled: the player announces "I fired,"
## and this arena decides that, in the gym, firing means "ask the spawner to
## spawn it, crediting the player as the source so it can't hit itself."

@onready var _player: Player = $Player
@onready var _spawner: AttackSpawner = $AttackSpawner

func _ready() -> void:
	_player.attack_fired.connect(_on_player_attack_fired)

func _on_player_attack_fired(attack: AttackDef, origin: Vector2, aim_direction: Vector2) -> void:
	_spawner.spawn_attack(attack, origin, aim_direction, _player)
