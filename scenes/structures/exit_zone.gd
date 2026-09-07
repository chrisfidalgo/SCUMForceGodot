class_name ExitZone
extends Area2D
## exit_zone.gd — the arena's exit trigger; characters that reach it "survive."
##
## An Area2D is Godot's overlap-detector node (unlike a StaticBody2D, it never
## blocks movement — it just reports who passed through it). Full mini-banking
## and win/loss logic land in Phase 2; for the gym this zone only ANNOUNCES that
## someone reached it. The arena (gym.gd) decides what that means — banking the
## escorted minis and logging a survivor — so this scene stays reusable when
## Phase 2 wants a different consequence.

## Someone reached the exit. The arena decides what happens next.
signal character_exited(body: Node2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	character_exited.emit(body)
