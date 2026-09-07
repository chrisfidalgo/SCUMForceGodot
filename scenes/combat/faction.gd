class_name Faction
extends RefCounted
## Faction — whose side something is on.
##
## The eight physics layers (02-ARCHITECTURE.md §4) encode HEIGHT, not SIDE:
## `hurt_low`/`hurt_high` say "this can be hit by a low/high attack", never "this
## belongs to the enemy". That is deliberate — the channel system is the game's
## identity and every unit shares it — but it means collision alone cannot tell a
## projectile whether it just found a valid target or a teammate.
##
## The layers are frozen after Phase 0 and none are free, so side is resolved in
## script instead. Anything that can shoot or be shot exposes a `faction`
## property; everything else reads NEUTRAL and is hittable by all, which keeps
## the target dummies working untouched.
##
## Never instanced; call the static helpers, e.g. `Faction.of(node)`.

enum Team { NEUTRAL, PLAYER, ENEMY }

## Read a node's team. Looks at the node itself, then the entity that owns it,
## then its parent — a hurtbox is usually a child Area2D, so the faction lives on
## the body above it rather than on the box that was actually hit.
static func of(node: Object) -> Team:
	if node == null or not is_instance_valid(node):
		return Team.NEUTRAL
	for candidate in [node, (node as Node).owner if node is Node else null,
			(node as Node).get_parent() if node is Node else null]:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var value: Variant = candidate.get("faction")
		if value != null and typeof(value) == TYPE_INT:
			return value as Team
	return Team.NEUTRAL

## True when a projectile fired by `source_team` should refuse to damage
## `target_team`. NEUTRAL is deliberately hittable by everyone (target dummies),
## and a NEUTRAL shooter can hit anything (debug/hand-placed projectiles).
static func is_friendly(source_team: Team, target_team: Team) -> bool:
	if source_team == Team.NEUTRAL or target_team == Team.NEUTRAL:
		return false
	return source_team == target_team
