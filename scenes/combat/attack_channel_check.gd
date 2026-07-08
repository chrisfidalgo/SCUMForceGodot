extends SceneTree
## attack_channel_check.gd — headless proof for packet P1c.
##
## Run with:
##   godot --headless --path . --script res://scenes/combat/attack_channel_check.gd
##
## Part 1 asserts the ChannelMasks bitmask identity directly (the "identity
## guarantee" the packet brief calls out explicitly). Part 2 builds a real,
## tiny scene tree — spawner, placeholder hurtboxes, placeholder blockers —
## and fires the four actual AttackDef .tres files through AttackSpawner to
## prove 03-GYM-SPEC.md §7.4 (channel x elevation) and §7.5 (structures)
## end to end, plus the `source` ignore-node behavior. Exits 0 if every
## assertion passes, 1 otherwise. Not part of the shipped game.

const TP_ROLL: AttackDef = preload("res://resources/attacks/tp_roll.tres")
const LONG_TOSS: AttackDef = preload("res://resources/attacks/long_toss.tres")
const CHEESE_WHEEL: AttackDef = preload("res://resources/attacks/cheese_wheel.tres")
const RIND_SLAM: AttackDef = preload("res://resources/attacks/rind_slam.tres")

const LAYER_HURT_LOW := 4
const LAYER_HURT_HIGH := 5
const LAYER_BLOCK_LOW := 6
const LAYER_BLOCK_HIGH := 7

var _pass := 0
var _fail := 0
var _scene_root: Node2D

func _initialize() -> void:
	_scene_root = Node2D.new()
	root.add_child(_scene_root)
	current_scene = _scene_root
	# Let the engine finish frame-0 setup before anything below relies on
	# get_tree() inside a freshly-added node (AttackSpawner's add_child calls
	# would otherwise race the tree's own startup on this very first frame).
	await process_frame

	_check_masks()
	await _check_elevation_matrix()
	await _check_structure_matrix()
	await _check_burst()
	await _check_ignore_node()

	print("\n=== attack_channel_check: %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _expect(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("PASS - %s" % description)
	else:
		_fail += 1
		print("FAIL - %s" % description)

## Part 1 — the mask helper is the identity guarantee: LOW must include
## hurt_low+block_low and exclude the high layers; HIGH the mirror image
## (and must NOT include block_low — that's why HIGH shots lob over low
## walls); BOTH must include all four.
func _check_masks() -> void:
	print("-- mask helper (identity guarantee) --")
	var low_bit := ChannelMasks.layer_bit(LAYER_HURT_LOW)
	var low_block_bit := ChannelMasks.layer_bit(LAYER_BLOCK_LOW)
	var high_bit := ChannelMasks.layer_bit(LAYER_HURT_HIGH)
	var high_block_bit := ChannelMasks.layer_bit(LAYER_BLOCK_HIGH)

	var low_mask := ChannelMasks.mask_for_channel(AttackDef.Channel.LOW)
	_expect(low_mask & low_bit != 0 and low_mask & low_block_bit != 0, "LOW mask includes hurt_low + block_low")
	_expect(low_mask & high_bit == 0 and low_mask & high_block_bit == 0, "LOW mask excludes hurt_high + block_high")

	var high_mask := ChannelMasks.mask_for_channel(AttackDef.Channel.HIGH)
	_expect(high_mask & high_bit != 0 and high_mask & high_block_bit != 0, "HIGH mask includes hurt_high + block_high")
	_expect(high_mask & low_bit == 0 and high_mask & low_block_bit == 0, "HIGH mask excludes hurt_low + block_low (why HIGH shots lob over low walls)")

	var both_mask := ChannelMasks.mask_for_channel(AttackDef.Channel.BOTH)
	_expect(
		both_mask & low_bit != 0 and both_mask & high_bit != 0 and both_mask & low_block_bit != 0 and both_mask & high_block_bit != 0,
		"BOTH mask includes all four hurt/block layers"
	)

func _make_hurtbox(label: String, layers: Array[int], pos: Vector2, parent: Node = null) -> TestHurtbox:
	var hb := TestHurtbox.new()
	hb.label_text = label
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	hb.add_child(cs)
	hb.collision_layer = 0
	hb.collision_mask = 0
	for l in layers:
		hb.set_collision_layer_value(l, true)
	var actual_parent: Node = parent if parent != null else _scene_root
	actual_parent.add_child(hb)
	hb.global_position = pos
	return hb

func _make_blocker(layers: Array[int], pos: Vector2) -> Area2D:
	var blocker := Area2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 70)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	blocker.add_child(cs)
	blocker.collision_layer = 0
	blocker.collision_mask = 0
	for l in layers:
		blocker.set_collision_layer_value(l, true)
	_scene_root.add_child(blocker)
	blocker.global_position = pos
	return blocker

func _spawner() -> AttackSpawner:
	var s := AttackSpawner.new()
	_scene_root.add_child(s)
	return s

func _fire_and_wait(spawner: AttackSpawner, attack: AttackDef, origin: Vector2, direction: Vector2, seconds: float, source: Node = null) -> void:
	spawner.spawn_attack(attack, origin, direction, source)
	await create_timer(seconds).timeout

## queue_free() defers actual removal; give it two process frames before the
## next case reuses the same coordinates.
func _clear_scene() -> void:
	for child in _scene_root.get_children():
		child.queue_free()
	await process_frame
	await process_frame

## Part 2 — 03-GYM-SPEC.md §7.4: LOW hits GROUND & TALL, never ELEVATED;
## HIGH hits ELEVATED & TALL, never GROUND; BOTH hits all three.
func _check_elevation_matrix() -> void:
	print("\n-- §7.4 channel x elevation --")
	var cases := [
		{"attack": TP_ROLL, "name": "TP Roll (LOW)", "ground": true, "elevated": false, "tall": true},
		{"attack": LONG_TOSS, "name": "Long Toss (HIGH)", "ground": false, "elevated": true, "tall": true},
		{"attack": CHEESE_WHEEL, "name": "Cheese Wheel (BOTH)", "ground": true, "elevated": true, "tall": true},
	]
	for test_case in cases:
		var attack: AttackDef = test_case["attack"]
		for elevation in ["ground", "elevated", "tall"]:
			var layers: Array[int] = []
			match elevation:
				"ground":
					layers = [LAYER_HURT_LOW]
				"elevated":
					layers = [LAYER_HURT_HIGH]
				"tall":
					layers = [LAYER_HURT_LOW, LAYER_HURT_HIGH]
			var spawner := _spawner()
			var hb := _make_hurtbox(elevation, layers, Vector2(0, -100))
			var wait_time: float = (100.0 / attack.projectile_speed) + 0.2
			await _fire_and_wait(spawner, attack, Vector2.ZERO, Vector2.UP, wait_time)
			var expected: bool = test_case[elevation]
			var got: bool = hb.hit_count > 0
			_expect(got == expected, "%s vs %s dummy -> hit=%s (expected %s)" % [test_case["name"], elevation.to_upper(), got, expected])
			await _clear_scene()

## Part 2 — 03-GYM-SPEC.md §7.5: low wall stops LOW but not HIGH; tall wall
## stops everything; BOTH is stopped by the first blocker of either channel.
func _check_structure_matrix() -> void:
	print("\n-- §7.5 structures --")
	var wall_cases := [
		{"wall": "low_wall", "layers": [LAYER_BLOCK_LOW]},
		{"wall": "tall_wall", "layers": [LAYER_BLOCK_LOW, LAYER_BLOCK_HIGH]},
	]
	var attack_cases := [
		{"attack": TP_ROLL, "name": "TP Roll (LOW)", "passes_low_wall": false, "passes_tall_wall": false},
		{"attack": LONG_TOSS, "name": "Long Toss (HIGH)", "passes_low_wall": true, "passes_tall_wall": false},
		{"attack": CHEESE_WHEEL, "name": "Cheese Wheel (BOTH)", "passes_low_wall": false, "passes_tall_wall": false},
	]
	for wall_case in wall_cases:
		for atk_case in attack_cases:
			var attack: AttackDef = atk_case["attack"]
			var spawner := _spawner()
			var wall_layers: Array[int] = []
			wall_layers.assign(wall_case["layers"])
			_make_blocker(wall_layers, Vector2(0, -60))
			var behind := _make_hurtbox("behind_" + wall_case["wall"], [LAYER_HURT_LOW, LAYER_HURT_HIGH], Vector2(0, -120))
			var wait_time: float = (120.0 / attack.projectile_speed) + 0.3
			await _fire_and_wait(spawner, attack, Vector2.ZERO, Vector2.UP, wait_time)
			var expect_hit: bool = atk_case["passes_low_wall"] if wall_case["wall"] == "low_wall" else atk_case["passes_tall_wall"]
			var got: bool = behind.hit_count > 0
			_expect(got == expect_hit, "%s vs %s -> reached far dummy=%s (expected %s)" % [atk_case["name"], wall_case["wall"], got, expect_hit])
			await _clear_scene()

## Rind Slam: FIXED radial burst, LOW channel — hits a nearby GROUND hurtbox,
## does NOT hit an ELEVATED-only hurtbox even though it's within radius.
func _check_burst() -> void:
	print("\n-- Rind Slam (FIXED radial burst) --")
	var spawner := _spawner()
	var near_ground := _make_hurtbox("burst_ground_20px", [LAYER_HURT_LOW], Vector2(20, 0))
	var near_elevated := _make_hurtbox("burst_elevated_40px", [LAYER_HURT_HIGH], Vector2(0, -40))
	spawner.spawn_attack(RIND_SLAM, Vector2.ZERO, Vector2.UP, null)
	await create_timer(0.3).timeout
	_expect(near_ground.hit_count == 1, "Rind Slam hits a GROUND hurtbox 20px away (radius %.0fpx)" % RIND_SLAM.range_px)
	_expect(near_elevated.hit_count == 0, "Rind Slam (LOW channel) does NOT hit an ELEVATED-only hurtbox within radius")
	await _clear_scene()

## `source` lets the spawner's caller (the firer) exclude its own hurtbox.
func _check_ignore_node() -> void:
	print("\n-- source / ignore_node --")
	var spawner := _spawner()
	var firer := Node2D.new()
	_scene_root.add_child(firer)
	var own_hurtbox := _make_hurtbox("own_hurtbox", [LAYER_HURT_LOW], Vector2.ZERO, firer)
	var far_target := _make_hurtbox("far_target", [LAYER_HURT_LOW], Vector2(0, -100))
	await _fire_and_wait(spawner, TP_ROLL, Vector2.ZERO, Vector2.UP, 0.6, firer)
	_expect(own_hurtbox.hit_count == 0, "projectile ignores the firer's own hurtbox (source param)")
	_expect(far_target.hit_count == 1, "...and still hits a real target beyond it")
	await _clear_scene()
