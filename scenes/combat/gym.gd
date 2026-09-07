extends Node2D
## gym.gd — the combat-testing arena, and the place every packet meets.
##
## The arena owns the wiring, not the behaviour. Each piece (player, enemies,
## minis, spawner, exit) knows only its own job and announces what happened via
## a signal; this script decides what those announcements MEAN in the gym. That
## is why the player does not spawn its own projectiles and an enemy does not
## know what a mini is — Phase 2 can react differently to the same signals
## without editing any of them.
##
## What it coordinates:
##   • firing        — player/enemy `attack_fired` -> AttackSpawner
##   • going down    — player `went_down` -> spawn a rescuable Mini, offer a swap
##   • the escort    — mini pickup, follow chain, 2+ speed penalty, drop on death
##   • the exit      — banking escorted minis and logging a survivor
##   • debug         — spawn/reset/swap entry points the debug tray calls

const MINI_SCENE: PackedScene = preload("res://scenes/characters/mini.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

## The gym roster. Phase 2 replaces this with a real character-select flow.
const ROSTER: Array[String] = [
	"res://resources/characters/johnny.tres",
	"res://resources/characters/curt.tres",
]

## Move-speed multiplier while escorting 2 or more minis. Escorting exactly one
## is free — the penalty is the risk/reward dial from PROJECT_CONTEXT.md, and a
## flat -25% is the placeholder the owner signed off on. Tune by feel.
@export var escort_penalty_multiplier: float = 0.75

## Emitted whenever the escort chain changes length, for the HUD.
signal escort_changed(count: int)
## Emitted when a character banks at the exit, or goes down, so the HUD/log react.
signal character_banked(name: String, minis_banked: int)

var _roster_index := 0
var _escort_chain: Array[Mini] = []

@onready var _player: Player = $Player
@onready var _spawner: AttackSpawner = $AttackSpawner
@onready var _spawn_marker: Marker2D = $PlayerSpawn
@onready var _exit_zone: ExitZone = $ExitZone


func _ready() -> void:
	randomize()
	_player.attack_fired.connect(_on_attack_fired.bind(_player))
	_player.went_down.connect(_on_player_went_down)
	_exit_zone.character_exited.connect(_on_character_exited)
	# Enemies placed by hand in the editor still need their firing wired up.
	for node in get_tree().get_nodes_in_group("enemies"):
		_register_enemy(node as Enemy)


## One handler for every shooter. `source` is bound per-connection so the
## projectile knows who fired it — that drives both self-ignore and the faction
## check that stops an enemy shooting the enemy in front of it.
func _on_attack_fired(attack: AttackDef, origin: Vector2, aim: Vector2, source: Node) -> void:
	_spawner.spawn_attack(attack, origin, aim, source)


# --- Enemies -------------------------------------------------------------------

## Spawn an enemy of the given archetype. Used by the debug tray; `at` defaults
## to a random point around the arena edge.
func spawn_enemy(archetype: Enemy.Archetype, elevation: Enemy.Elevation = Enemy.Elevation.GROUND,
		at: Vector2 = Vector2.INF) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.archetype = archetype
	enemy.elevation = elevation
	# Give the shooting archetypes something to shoot. A Turret gets the lobbed
	# shot so it can threaten a player hiding behind the low wall; the Seeker
	# gets the flat shot that the wall actually stops.
	match archetype:
		Enemy.Archetype.WANDERER:
			enemy.move_speed = 40.0
			enemy.max_half_hearts = 2
		Enemy.Archetype.TURRET:
			enemy.move_speed = 0.0
			enemy.max_half_hearts = 2
			enemy.fire_cooldown_sec = 1.8
			enemy.attack = load("res://resources/attacks/bag_lob.tres")
		Enemy.Archetype.SEEKER:
			enemy.move_speed = 55.0
			enemy.max_half_hearts = 3
			enemy.fire_cooldown_sec = 2.2
			enemy.preferred_range_px = 120.0
			enemy.attack = load("res://resources/attacks/bag_shot.tres")
	add_child(enemy)
	enemy.global_position = at if at != Vector2.INF else _random_edge_point()
	_register_enemy(enemy)
	return enemy


func _register_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.attack_fired.is_connected(_on_attack_fired):
		enemy.attack_fired.connect(_on_attack_fired.bind(enemy))


func _random_edge_point() -> Vector2:
	var margin := 40.0
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(margin, 640 - margin), margin)
		1: return Vector2(randf_range(margin, 640 - margin), 360 - margin)
		2: return Vector2(margin, randf_range(margin, 360 - margin))
		_: return Vector2(640 - margin, randf_range(margin, 360 - margin))


# --- Going down, and the escort chain -------------------------------------------

func _on_player_went_down(character: CharacterDef, at_position: Vector2) -> void:
	# Anyone being escorted lies back down where they stand — never lost.
	for mini in _escort_chain:
		if is_instance_valid(mini):
			mini.drop()
	_escort_chain.clear()
	escort_changed.emit(0)
	_drop_mini_for(character, at_position)
	print("down: %s — swap (F5) to keep playing" % character.display_name)


## Turn a character into a rescuable mini lying at `at_position`.
func _drop_mini_for(character: CharacterDef, at_position: Vector2) -> Mini:
	var mini: Mini = MINI_SCENE.instantiate()
	mini.character_def = character
	add_child(mini)
	mini.global_position = at_position
	mini.rescued.connect(_on_mini_rescued)
	return mini


func _on_mini_rescued(mini: Mini) -> void:
	# A dead character cannot rescue anyone, and nobody joins the line twice —
	# without this second guard a mini could end up as its own leader and freeze.
	if mini == null or _player.health.is_dead() or _escort_chain.has(mini):
		return
	# Attach to the back of the line: the player, or whoever is currently last.
	var leader: Node2D = _escort_chain[-1] if not _escort_chain.is_empty() else _player
	if leader == mini:
		leader = _player
	mini.attach_to(leader)
	_escort_chain.append(mini)
	_apply_escort_penalty()
	escort_changed.emit(_escort_chain.size())


## Escorting exactly one is free; two or more costs speed.
func _apply_escort_penalty() -> void:
	_player.speed_multiplier = escort_penalty_multiplier if _escort_chain.size() >= 2 else 1.0


func escort_count() -> int:
	return _escort_chain.size()


## The character currently being played. The HUD and debug tray ask for this
## rather than reaching into the scene tree, so the gym stays the single owner
## of who is active — which matters once Phase 2 does real roster swapping.
func active_player() -> Player:
	return _player


func is_invincible() -> bool:
	return _player.health.invulnerable


# --- The exit -------------------------------------------------------------------

func _on_character_exited(body: Node2D) -> void:
	if body != _player or _player.health.is_dead():
		return
	var banked := _escort_chain.size()
	for mini in _escort_chain:
		if is_instance_valid(mini):
			mini.queue_free()
	_escort_chain.clear()
	_player.speed_multiplier = 1.0
	escort_changed.emit(0)
	var who: String = _player.character_def.display_name if _player.character_def else "?"
	print("survived: %s (banked %d mini(s))" % [who, banked])
	character_banked.emit(who, banked)


# --- Debug entry points (the tray calls these) -----------------------------------

## Force the active character down without having to lose a fight.
func debug_force_down() -> void:
	if _player.health.is_dead():
		return
	_player.health.invulnerable = false
	_player.receive_hit(_player.health.current())


## Swap to the next roster member, respawning at the marker. This is the gym's
## stand-in for the real per-encounter character selection in Phase 2.
func debug_swap_character() -> void:
	_roster_index = (_roster_index + 1) % ROSTER.size()
	var def: CharacterDef = load(ROSTER[_roster_index])
	_player.set_character(def)
	_player.global_position = _spawn_marker.global_position
	_player.speed_multiplier = 1.0
	print("swapped to: %s" % def.display_name)


func debug_toggle_invincible() -> bool:
	_player.health.invulnerable = not _player.health.invulnerable
	return _player.health.invulnerable


## Clear the field and put everything back to a known state.
func debug_reset() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("minis"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("effects"):
		node.queue_free()
	_escort_chain.clear()
	escort_changed.emit(0)
	for dummy in get_tree().get_nodes_in_group("dummies"):
		if dummy.has_method("reset_counter"):
			dummy.reset_counter()
	_player.set_character(_player.character_def)
	_player.global_position = _spawn_marker.global_position
	print("gym reset")
