extends CanvasLayer
## combat_hud.gd — the minimal in-combat readout (03-GYM-SPEC.md §6).
##
## Placeholder art throughout: hearts are drawn as coloured boxes, cooldowns as
## bars. The point is legibility during the core-feel playtest, not looks — the
## owner needs to see, without pausing, how much health is left, whether an
## attack is ready, and how many minis are being dragged along.
##
## Hearts are drawn at HALF-heart granularity because that is the game's damage
## unit (PROJECT_CONTEXT.md): a standard hit costs half a heart, so a HUD that
## only showed whole hearts would make half of all damage invisible.
##
## Reads from signals, not by polling health every frame — the exception is the
## cooldown bars, which are continuous values with no meaningful "changed" event.

const HEART_PX := 9
const HEART_GAP := 2

var _player: Player = null
var _gym: Node = null

var _hearts: Control = null
var _name_label: Label = null
var _primary_bar: ProgressBar = null
var _secondary_bar: ProgressBar = null
var _escort_label: Label = null


func _ready() -> void:
	_gym = get_parent()
	# Godot readies children before parents, so the gym's @onready node
	# references do not exist yet at this point. Wait for it before asking it
	# anything.
	if not _gym.is_node_ready():
		await _gym.ready
	_player = _gym.active_player()
	_build_ui()
	_player.health_changed.connect(_on_health_changed)
	if _gym.has_signal("escort_changed"):
		_gym.escort_changed.connect(_on_escort_changed)
	_on_health_changed(_player.health.current(), _player.health.max_half_hearts)
	_on_escort_changed(0)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# Cooldowns are continuous; a signal per frame would be worse than polling.
	_primary_bar.value = _player.primary_cooldown_ratio() * 100.0
	_secondary_bar.value = _player.secondary_cooldown_ratio() * 100.0
	var name_text: String = _player.character_def.display_name if _player.character_def else "?"
	if _player.health.is_dead():
		name_text += "  — DOWN (F5 to swap)"
	elif _player.health.invulnerable:
		name_text += "  — invulnerable"
	_name_label.text = name_text


func _on_health_changed(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	# One box per half-heart: filled if that half is still alive.
	for i in range(maximum):
		var pip := ColorRect.new()
		pip.size = Vector2(HEART_PX * 0.5, HEART_PX)
		pip.position = Vector2(i * (HEART_PX * 0.5 + HEART_GAP), 0)
		# Pair the halves visually so two pips read as one heart.
		if i % 2 == 1:
			pip.position.x -= HEART_GAP - 1
		pip.color = Color(0.9, 0.25, 0.3) if i < current else Color(0.25, 0.15, 0.18)
		_hearts.add_child(pip)


func _on_escort_changed(count: int) -> void:
	if _escort_label == null:
		return
	if count == 0:
		_escort_label.text = "escorting: none"
	elif count == 1:
		_escort_label.text = "escorting: 1  (no penalty)"
	else:
		_escort_label.text = "escorting: %d  (SLOWED)" % count


func _build_ui() -> void:
	var root := Control.new()
	root.position = Vector2(8, 6)
	add_child(root)

	_hearts = Control.new()
	_hearts.position = Vector2(0, 0)
	root.add_child(_hearts)

	_name_label = _label(Vector2(0, 12), Color(1, 1, 1))
	root.add_child(_name_label)

	_primary_bar = _bar(Vector2(0, 24), Color(0.4, 0.8, 1.0))
	root.add_child(_primary_bar)
	root.add_child(_bar_caption(Vector2(46, 23), "J primary"))

	_secondary_bar = _bar(Vector2(0, 33), Color(1.0, 0.8, 0.35))
	root.add_child(_secondary_bar)
	root.add_child(_bar_caption(Vector2(46, 32), "K secondary"))

	_escort_label = _label(Vector2(0, 44), Color(0.7, 0.9, 1.0))
	root.add_child(_escort_label)


func _label(pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", color)
	return l


func _bar_caption(pos: Vector2, text: String) -> Label:
	var l := _label(pos, Color(0.65, 0.65, 0.7))
	l.text = text
	return l


## A cooldown bar reads FULL when the attack is on cooldown and empties as it
## becomes ready, so "empty = go" matches the eye's read of a depleting timer.
func _bar(pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(42, 6)
	bar.custom_minimum_size = Vector2(42, 6)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.18)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar
