class_name TestHurtbox
extends Area2D
## TestHurtbox — placeholder hurtbox used only by projectile_test.tscn (and
## its headless check) to prove the channel system without packet P1b's real
## target dummies. A hurtbox is any Area2D on hurt_low/hurt_high exposing
## `receive_hit(damage_half_hearts)` — this is the minimal thing that
## satisfies that contract, plus a hit counter and a flash so a human can see
## it working. Not part of the shipped game.

@export var label_text: String = "hurtbox"

var hit_count: int = 0

@onready var _label: Label = get_node_or_null("Label")

func _ready() -> void:
	_refresh_label()

func receive_hit(damage_half_hearts: int) -> void:
	hit_count += 1
	_refresh_label()
	modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

func _refresh_label() -> void:
	if _label:
		_label.text = "%s\nhits: %d" % [label_text, hit_count]
