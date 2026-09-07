class_name AttackSpawner
extends Node
## AttackSpawner — turns "this AttackDef fired from here, facing there" into an
## actual projectile in the world. It reads everything from the AttackDef and
## never hardcodes an attack's numbers.
##
## Wired by the gym: player.attack_fired.connect(
##   func(a, o, d): spawner.spawn_attack(a, o, d, player))
##
## A Node is the plainest scene-tree building block (no transform, no visuals) —
## the spawner needs no position of its own since spawn_attack() is handed an
## explicit world-space origin.

## Fallback projectile used when an AttackDef's own projectile_scene is empty.
@export var default_projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

## Where spawned projectiles are parented. Empty = this spawner's own parent
## (the arena). Deliberately NOT get_tree().current_scene: that is only the arena
## while the gym is run directly with F6 — once Phase 2 loads the arena as a
## child screen via GameFlow, current_scene is main.tscn and projectiles would be
## parented outside the arena they belong to.
@export var projectile_container: Node = null

func _projectile_parent() -> Node:
	if projectile_container != null and is_instance_valid(projectile_container):
		return projectile_container
	return get_parent()

func spawn_attack(attack: AttackDef, origin: Vector2, aim_direction: Vector2, source: Node) -> void:
	if attack == null:
		push_warning("AttackSpawner.spawn_attack: attack is null, nothing spawned.")
		return
	var scene: PackedScene = attack.projectile_scene if attack.projectile_scene != null else default_projectile_scene
	if scene == null:
		push_error("AttackSpawner: no projectile_scene on the attack and no default set.")
		return
	var proj := scene.instantiate() as Projectile
	if proj == null:
		push_error("AttackSpawner: projectile scene's root is not a Projectile.")
		return
	proj.setup(attack, aim_direction, source)
	var parent := _projectile_parent()
	if parent == null:
		push_error("AttackSpawner: no parent to add the projectile to.")
		return
	parent.add_child(proj)
	proj.global_position = origin
