extends Encounter
## gym.gd — the combat-testing arena: an Encounter with `sandbox = true`.
##
## Everything that is a real rule (firing, enemies, going down, the escort, the
## exit, deploying) lives in Encounter. What is left here is the gym's own
## debug entry points, which the debug tray calls, plus the dummy reset.

var _roster_index := 0


## Force the active character down without having to lose a fight.
func debug_force_down() -> void:
	if _player.health.is_dead():
		return
	_player.health.invulnerable = false
	_player.receive_hit(_player.health.current())


## Swap to the next default_roster member, respawning at the marker.
func debug_swap_character() -> void:
	if default_roster.is_empty():
		return
	_roster_index = (_roster_index + 1) % default_roster.size()
	var def: CharacterDef = default_roster[_roster_index]
	deploy(def)
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
