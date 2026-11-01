class_name Encounter
extends Node2D
## encounter.gd — the base every combat level shares (06-ENEMY-BEHAVIOURS-AND-ENCOUNTERS.md §3).
##
## An Encounter owns the WIRING and the RULES of one combat stage, not the
## behaviour of any piece in it. Player, enemies, minis, spawner and exit each
## know only their own job and announce what happened via a signal; this script
## decides what those announcements mean:
##   • firing        — player/enemy `attack_fired` -> AttackSpawner
##   • deploying     — pick one character from the pool, spawn them at PlayerSpawn
##   • going down    — `went_down` -> a rescuable Mini, then pick the next character
##   • the escort    — pickup, follow chain, 2+ speed penalty, drop on death
##   • the exit      — banking escorted minis; the character is "survived"
##   • resolving     — CLEARED / ESCAPED / LOST / TIMED_OUT, reported exactly once
##
## It READS RunState (who is in the pool, and at what health) but never writes it.
## Writing results back is the run harness's job; this only emits `resolved`.
##
## Levels are inherited scenes of `encounter_base.tscn`; the gym is the sandbox
## flavour (`sandbox = true`) that never resolves.

const MINI_SCENE: PackedScene = preload("res://scenes/characters/mini.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")

enum Outcome { CLEARED, ESCAPED, LOST, TIMED_OUT }

## Shown on the HUD. Empty falls back to the scene's node name.
@export var display_name: String = ""
## A clear-only room: the exit is disabled and hidden, so only CLEARED / LOST / TIMED_OUT.
@export var is_boss: bool = false
## The gym flavour: never resolves, the pool never shrinks, the timer is ignored.
@export var sandbox: bool = false
## Seconds before Time's Out. 0 = no timer.
@export var time_limit_sec: float = 0.0
## Move-speed multiplier while escorting 2 or more minis. Escorting exactly one
## is free — the penalty is the risk/reward dial from PROJECT_CONTEXT.md, and a
## flat -25% is the placeholder the owner signed off on. Tune by feel.
@export var escort_penalty_multiplier: float = 0.75
## Seconds after a character appears during which enemies ignore them and they
## can't be hurt — so a character never deploys straight into a waiting crowd.
## The spawn pad stays lit for the duration. 0 = no grace.
@export var deploy_grace_sec: float = 1.0
## Used when RunState.roster is empty (running a level alone with F6).
@export var default_roster: Array[CharacterDef] = []
## How far in from the screen edge a debug-spawned enemy lands when no position is given.
@export var edge_spawn_margin_px: float = 40.0

## Emitted whenever the escort chain changes length, for the HUD.
signal escort_changed(count: int)
## Emitted when a character banks at the exit, so the HUD/log react.
signal character_banked(name: String, minis_banked: int)
## The pool needs a pick. The DeployPicker answers by calling `deploy()`.
signal deploy_requested(choices: Array[CharacterDef])
signal timer_changed(seconds_left: float)
signal timer_expired
## Emitted exactly once, after which this encounter stops running.
signal resolved(outcome: Outcome, report: Dictionary)

## Characters not yet deployed, as {"def": CharacterDef, "half_hearts": int}.
## In a sandbox it holds everyone, permanently.
var _pool: Array[Dictionary] = []
## The entry for whoever is on the field right now (empty while choosing).
var _active_entry: Dictionary = {}
## Bumped on every deploy so a grace timer from an earlier deploy can't end the
## current one's grace early.
var _deploy_serial := 0
var _escort_chain: Array[Mini] = []
var _enemies: Array[Enemy] = []
var _had_enemies := false
var _time_left := 0.0
var _resolved := false
var _paused_by_picker := false

## Report accumulators, keyed by CharacterDef.resource_path.
var _survived: Dictionary = {}
var _banked: Array[String] = []
var _downed: Array[String] = []

var _body_layer := 0
var _hurtbox_layer := 0

@onready var _player: Player = $Player
@onready var _spawner: AttackSpawner = $AttackSpawner
@onready var _spawn_marker: Marker2D = $PlayerSpawn
## Optional visual marker under PlayerSpawn; pulses while nobody is deployed.
@onready var _spawn_pad: SpawnPad = get_node_or_null("PlayerSpawn/SpawnPad") as SpawnPad
@onready var _exit_zone: ExitZone = get_node_or_null("ExitZone") as ExitZone
@onready var _picker: DeployPicker = get_node_or_null("DeployPicker") as DeployPicker


func _ready() -> void:
	randomize()
	_body_layer = _player.collision_layer
	var hurtbox := _player.get_node_or_null("Hurtbox") as CollisionObject2D
	_hurtbox_layer = hurtbox.collision_layer if hurtbox != null else 0
	_player.attack_fired.connect(_on_attack_fired.bind(_player))
	_player.went_down.connect(_on_player_went_down)
	if _exit_zone != null:
		if is_boss:
			_exit_zone.visible = false
			_exit_zone.set_deferred("monitoring", false)
		else:
			_exit_zone.character_exited.connect(_on_character_exited)
	# Enemies placed by hand in the editor still need their firing wired up.
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(node):
			register_enemy(node as Enemy)
	if not sandbox and not _had_enemies:
		push_error("Encounter '%s' has no enemies — every combat stage must have at least one."
				% (scene_file_path if scene_file_path != "" else str(name)))
	if _picker != null:
		_picker.picked.connect(deploy)
	_time_left = time_limit_sec
	_pool = _build_pool()
	_set_player_active(false)
	_request_deploy()


func _physics_process(delta: float) -> void:
	if sandbox or _resolved or time_limit_sec <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	timer_changed.emit(_time_left)
	if _time_left <= 0.0:
		timer_expired.emit()
		_resolve(Outcome.TIMED_OUT)


func _exit_tree() -> void:
	# Never leave the whole game frozen behind us if we are freed mid-pick.
	_unpause()


## One handler for every shooter. `source` is bound per-connection so the
## projectile knows who fired it — that drives both self-ignore and the faction
## check that stops an enemy shooting the enemy in front of it.
func _on_attack_fired(attack: AttackDef, origin: Vector2, aim: Vector2, source: Node) -> void:
	_spawner.spawn_attack(attack, origin, aim, source)


# --- Enemies -------------------------------------------------------------------

## Spawn an enemy of the given type. `at` defaults to a random point near the
## screen edge. `def`, `elevation` and `patrol_route` are set BEFORE add_child so
## the enemy's own _ready sees its final configuration.
func spawn_enemy(def: EnemyDef, elevation: Enemy.Elevation = Enemy.Elevation.GROUND,
		at: Vector2 = Vector2.INF, patrol_route: Node2D = null) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	# Dynamic set: compiles against any Enemy version, and the properties are
	# plain exports on the new (def-driven) Enemy.
	enemy.set("def", def)
	enemy.elevation = elevation
	enemy.set("patrol_route", patrol_route)
	add_child(enemy)
	enemy.global_position = at if at != Vector2.INF else _random_edge_point()
	register_enemy(enemy)
	return enemy


## Hook an enemy into the encounter: its shots go through our spawner and its
## death counts toward CLEARED. Safe to call twice for the same enemy.
func register_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.attack_fired.is_connected(_on_attack_fired):
		enemy.attack_fired.connect(_on_attack_fired.bind(enemy))
	if not _enemies.has(enemy):
		_enemies.append(enemy)
		_had_enemies = true
		enemy.died.connect(func(_at: Vector2) -> void: _forget_enemy(enemy))
		enemy.tree_exited.connect(_forget_enemy.bind(enemy))


func _forget_enemy(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_check_cleared.call_deferred()


## Called deferred so enemies that just died (they queue_free) are already
## out of the list and never double-count.
func _check_cleared() -> void:
	if _resolved or sandbox or not _had_enemies:
		return
	for i in range(_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_enemies[i]):
			_enemies.remove_at(i)
	if _enemies.is_empty():
		_resolve(Outcome.CLEARED)


func _random_edge_point() -> Vector2:
	var size := get_viewport_rect().size
	var m := edge_spawn_margin_px
	match randi() % 4:
		0: return Vector2(randf_range(m, size.x - m), m)
		1: return Vector2(randf_range(m, size.x - m), size.y - m)
		2: return Vector2(m, randf_range(m, size.y - m))
		_: return Vector2(size.x - m, randf_range(m, size.y - m))


# --- The pool and deploying -----------------------------------------------------

func _build_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if not RunState.roster.is_empty():
		for member in RunState.roster:
			if member.status != "active":
				continue
			var def: CharacterDef = load(member.id) as CharacterDef
			if def == null:
				push_warning("Encounter: roster id '%s' is not a CharacterDef — skipped." % member.id)
				continue
			pool.append({"def": def, "half_hearts": member.half_hearts})
	else:
		for def in default_roster:
			if def != null:
				pool.append({"def": def, "half_hearts": def.max_half_hearts})
	return pool


## Characters that can still be picked.
func deployable() -> Array[CharacterDef]:
	var choices: Array[CharacterDef] = []
	for entry in _pool:
		choices.append(entry["def"])
	return choices


## Decide what happens next: resolve if nobody is left, auto-deploy when there is
## no real choice, otherwise pause the world and ask.
func _request_deploy() -> void:
	if _resolved:
		return
	if _pool.is_empty():
		_resolve(Outcome.ESCAPED if not _survived.is_empty() else Outcome.LOST)
		return
	if sandbox or _pool.size() == 1:
		deploy(_pool[0]["def"])
		return
	var choices := deployable()
	deploy_requested.emit(choices)
	if _picker == null:
		push_error("Encounter '%s' has no DeployPicker; deploying the first choice." % name)
		deploy(choices[0])
		return
	var hp_by_path: Dictionary = {}
	for entry in _pool:
		hp_by_path[(entry["def"] as CharacterDef).resource_path] = entry["half_hearts"]
	_picker.present(choices, hp_by_path)
	get_tree().paused = true
	_paused_by_picker = true


## Put `def` on the field at PlayerSpawn with their stored health. The picker
## calls this; so does the gym's swap.
func deploy(def: CharacterDef) -> void:
	if _resolved or def == null:
		return
	var idx := -1
	for i in _pool.size():
		if (_pool[i]["def"] as CharacterDef).resource_path == def.resource_path:
			idx = i
			break
	if idx >= 0:
		_active_entry = _pool[idx]
		if not sandbox:
			_pool.remove_at(idx)
	elif sandbox:
		_active_entry = {"def": def, "half_hearts": def.max_half_hearts}
	else:
		push_warning("Encounter: '%s' is not in the pool." % def.display_name)
		return
	_player.set_character(def)
	_player.health.set_current(maxi(1, _active_entry["half_hearts"]))
	_player.velocity = Vector2.ZERO
	_player.global_position = _spawn_marker.global_position
	_set_player_active(true)
	_start_deploy_grace()
	_unpause()


func _start_deploy_grace() -> void:
	_deploy_serial += 1
	if deploy_grace_sec <= 0.0:
		return
	var serial := _deploy_serial
	_player.on_field = false
	_player.health.invulnerable = true
	if _spawn_pad != null:
		_spawn_pad.awaiting = true
	await get_tree().create_timer(deploy_grace_sec, false).timeout
	# Ignore if a newer deploy happened, or the character already left the field.
	if serial != _deploy_serial or not _player.visible or _resolved:
		return
	_player.on_field = true
	_player.health.invulnerable = false
	if _spawn_pad != null:
		_spawn_pad.awaiting = false


## Between deploys nobody is on the field: the player is hidden, unhittable
## and uncontrollable. Physics-state changes, so call from a safe moment.
func _set_player_active(active: bool) -> void:
	_player.on_field = active
	_player.visible = active
	if _spawn_pad != null:
		_spawn_pad.awaiting = not active
	_player.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_player.collision_layer = _body_layer if active else 0
	var hurtbox := _player.get_node_or_null("Hurtbox") as CollisionObject2D
	if hurtbox != null:
		hurtbox.collision_layer = _hurtbox_layer if active else 0
	_player.health.invulnerable = not active


func _unpause() -> void:
	if _paused_by_picker:
		_paused_by_picker = false
		if is_inside_tree():
			get_tree().paused = false
	if _picker != null:
		_picker.dismiss()


# --- Going down, and the escort chain -------------------------------------------

func _on_player_went_down(character: CharacterDef, at_position: Vector2) -> void:
	if _resolved:
		return
	# Anyone being escorted lies back down where they stand — never lost.
	for mini in _escort_chain:
		if is_instance_valid(mini):
			mini.drop()
	_escort_chain.clear()
	escort_changed.emit(0)
	_drop_mini_for(character, at_position)
	if sandbox:
		print("down: %s — swap (F5) to keep playing" % character.display_name)
		return
	var path := character.resource_path
	if not _downed.has(path):
		_downed.append(path)
	_active_entry = {}
	print("down: %s" % character.display_name)
	_after_active_gone.call_deferred()


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
## rather than reaching into the scene tree, so the encounter stays the single
## owner of who is active.
func active_player() -> Player:
	return _player


func is_invincible() -> bool:
	return _player.health.invulnerable


## Seconds left on the clock (the full limit until play starts).
func time_left() -> float:
	return _time_left


# --- The exit -------------------------------------------------------------------

func _on_character_exited(body: Node2D) -> void:
	if _resolved or body != _player or _player.health.is_dead():
		return
	if not sandbox and _active_entry.is_empty():
		return
	var banked := _escort_chain.size()
	for mini in _escort_chain:
		if is_instance_valid(mini):
			if not sandbox and mini.character_def != null:
				var mini_path := mini.character_def.resource_path
				if not _banked.has(mini_path):
					_banked.append(mini_path)
				_downed.erase(mini_path)
			mini.queue_free()
	_escort_chain.clear()
	_player.speed_multiplier = 1.0
	escort_changed.emit(0)
	var who: String = _player.character_def.display_name if _player.character_def else "?"
	print("survived: %s (banked %d mini(s))" % [who, banked])
	character_banked.emit(who, banked)
	if sandbox:
		return
	_survived[_player.character_def.resource_path] = _player.health.current()
	_active_entry = {}
	_after_active_gone.call_deferred()


## The active character left the field (exited or went down): clear the stage
## of them, then pick the next one or resolve.
func _after_active_gone() -> void:
	if _resolved:
		return
	_set_player_active(false)
	_request_deploy()


# --- Resolution -----------------------------------------------------------------

func _resolve(outcome: Outcome) -> void:
	if _resolved or sandbox:
		return
	_resolved = true
	var survived: Dictionary = _survived.duplicate()
	# Winning the room while still standing counts as surviving it.
	if outcome == Outcome.CLEARED and not _active_entry.is_empty() \
			and not _player.health.is_dead():
		survived[_player.character_def.resource_path] = _player.health.current()
	var report := {
		"survived": survived,
		"banked": _banked.duplicate(),
		"downed": _downed.duplicate(),
	}
	_unpause()
	_player.health.invulnerable = true
	print("encounter resolved: %s %s" % [Outcome.keys()[outcome], report])
	# Stop gameplay for good: a disabled subtree runs no scripts and no physics,
	# so nothing can change after the report. The tree itself stays unpaused so
	# whatever harness is above us keeps running.
	process_mode = Node.PROCESS_MODE_DISABLED
	resolved.emit(outcome, report)
