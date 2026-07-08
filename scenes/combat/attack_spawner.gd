class_name AttackSpawner
extends Node
## AttackSpawner — reads an AttackDef and spawns whatever it describes: a
## traveling Projectile for FORWARD_VECTOR/FREE_CONE attacks, or a
## self-centered AttackBurst for FIXED attacks (radial bursts like Rind
## Slam). This is the only place "an AttackDef fired from here, aimed there"
## becomes an actual thing in the world; it never hardcodes any of the four
## attacks' numbers — everything comes from the AttackDef passed in.
##
## Wire-up (done by the integration pass, connecting packet P1a's player):
##   player.attack_fired.connect(func(a, o, d): spawner.spawn_attack(a, o, d, player))
##
## A Node is the plainest building block in Godot — no position, no visuals,
## just a place in the scene tree to hang a script. This spawner doesn't need
## a transform of its own since spawn_attack() always takes an explicit
## world-space origin.

## Fallback projectile scene used when an AttackDef's own projectile_scene is
## empty. All four P0 .tres files ship with projectile_scene unset — see
## docs/systems/attack-and-channel-system.md for why this fallback exists
## and what the integration pass should decide.
@export var default_projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

func spawn_attack(attack: AttackDef, origin: Vector2, aim_direction: Vector2, source: Node) -> void:
	if attack == null:
		push_warning("AttackSpawner.spawn_attack: attack is null, nothing spawned.")
		return
	if attack.aim_type == AttackDef.AimType.FIXED:
		_spawn_burst(attack, origin, source)
	else:
		_spawn_projectile(attack, origin, aim_direction, source)

func _spawn_projectile(attack: AttackDef, origin: Vector2, aim_direction: Vector2, source: Node) -> void:
	var scene: PackedScene = attack.projectile_scene if attack.projectile_scene != null else default_projectile_scene
	if scene == null:
		push_error("AttackSpawner: attack has no projectile_scene and no default_projectile_scene is set on the spawner.")
		return
	var direction: Vector2 = aim_direction.normalized() if aim_direction != Vector2.ZERO else Vector2.UP
	var proj := scene.instantiate() as Projectile
	if proj == null:
		push_error("AttackSpawner: projectile scene's root node is not a Projectile.")
		return
	proj.setup(direction, attack.projectile_speed, attack.range_px, attack.channel, attack.damage_half_hearts, source)
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin

func _spawn_burst(attack: AttackDef, origin: Vector2, source: Node) -> void:
	var burst := AttackBurst.new()
	burst.setup(attack.channel, attack.range_px, attack.damage_half_hearts, source)
	get_tree().current_scene.add_child(burst)
	burst.global_position = origin
	burst.detonate()
