extends Node2D
## enemy_sandbox.gd — P1h's own test arena for enemy behaviours. Not the gym and
## shares no code with it: it only copies the minimal wiring (every shooter's
## attack_fired -> AttackSpawner) so enemies can be exercised without Encounter.
## Run it with F6. Sentry/Patroller/Brawler/Turret are placed in the scene; the
## player is invincible so you can watch behaviours without dying.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

@onready var _player: Player = $Player
@onready var _spawner: AttackSpawner = $AttackSpawner


func _ready() -> void:
	_player.attack_fired.connect(_on_attack_fired.bind(_player))
	_player.health.invulnerable = true
	for node in get_tree().get_nodes_in_group("enemies"):
		register_enemy(node as Enemy)


func _on_attack_fired(attack: AttackDef, origin: Vector2, aim: Vector2, source: Node) -> void:
	_spawner.spawn_attack(attack, origin, aim, source)


func register_enemy(enemy: Enemy) -> void:
	if enemy != null and not enemy.attack_fired.is_connected(_on_attack_fired):
		enemy.attack_fired.connect(_on_attack_fired.bind(enemy))


## Spawn helper mirroring what an Encounter will do: set def/elevation/route
## BEFORE add_child, then position and register.
func spawn_enemy(def: EnemyDef, elevation: Enemy.Elevation = Enemy.Elevation.GROUND,
		at: Vector2 = Vector2(320, 180), patrol_route: Node2D = null) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.def = def
	enemy.elevation = elevation
	enemy.patrol_route = patrol_route
	add_child(enemy)
	enemy.global_position = at
	register_enemy(enemy)
	return enemy
