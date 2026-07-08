class_name ExitZone
extends Area2D
## exit_zone.gd — the arena's exit trigger; characters that reach it "survive."
##
## An Area2D is Godot's overlap-detector node (unlike a StaticBody2D, it never
## blocks movement — it just reports who passed through it). Full mini-banking
## and win/loss logic land in Phase 2; for the gym, reaching the zone just
## prints a console line so the structure/dummy sampler can be tested without
## a real win condition yet.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("survived: ", body.name)
