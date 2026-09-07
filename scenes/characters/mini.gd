class_name Mini
extends Area2D
## mini.gd — a downed character lying on the field, waiting to be rescued.
##
## When a character hits 0 half-hearts they do not vanish; they become one of
## these (03-GYM-SPEC.md §4). Walk the active character into it and it stands up
## and trails along behind. Get it to the exit and it is banked.
##
## An Area2D (overlap detector, never blocks movement) on the `pickup` physics
## layer, watching for the player's body. It is deliberately NOT on a hurt layer:
## a downed teammate cannot be shot again, so a rescue is never made impossible
## by bad luck — the design canon is explicit that minis are re-rescuable and
## never lost.
##
## Following is a simple trailing chain: each mini walks toward whatever is
## directly ahead of it in the line (the player, or the mini in front) and stops
## at `follow_gap_px`. No pathfinding — they will bump walls, and that is fine at
## this scale.

## Emitted when the active character touches this mini and picks it up.
signal rescued(mini: Mini)

## Who this is. Kept so a swap or a bank knows which roster member came back.
@export var character_def: CharacterDef

## How far behind its leader this mini trails.
@export var follow_gap_px: float = 14.0
## How fast it follows. Slightly above the fastest character so the chain does
## not stretch forever when the player sprints.
@export var follow_speed: float = 170.0

## What this mini walks behind: the player, or the mini ahead of it in the chain.
## Null means it is lying on the ground, waiting.
var follow_target: Node2D = null

@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $Label


func _ready() -> void:
	add_to_group("minis")
	body_entered.connect(_on_body_entered)
	_refresh_label()


func _physics_process(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	var to_leader: Vector2 = follow_target.global_position - global_position
	if to_leader.length() <= follow_gap_px:
		return
	global_position += to_leader.normalized() * follow_speed * delta


func _on_body_entered(body: Node2D) -> void:
	# Only the active character can rescue, and only once. A DOWNED character
	# cannot: the mini spawns underneath the body that just fell, so without this
	# the corpse would instantly "rescue" itself.
	if follow_target != null or not body.is_in_group("player"):
		return
	if body.get("health") != null and body.health.is_dead():
		return
	rescued.emit(self)


## Called by the gym when the escorting character goes down: the chain breaks and
## every mini lies back down exactly where it stood, re-rescuable later.
func drop() -> void:
	follow_target = null
	_refresh_label()


func attach_to(leader: Node2D) -> void:
	follow_target = leader
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	var who := character_def.display_name if character_def != null else "?"
	_label.text = who if follow_target != null else "%s (down)" % who
	if _visual != null:
		_visual.color = Color(0.5, 0.8, 1.0) if follow_target != null else Color(0.45, 0.45, 0.55)
