extends GlbChapter
class_name HillDifficulty
## Chapter 7. From an open base, three corridors diverge. Danger and Destruction
## look easier but end badly; the narrow middle way is steep and slow but true.
## A rest arbor on the middle path tempts you to linger and grow drowsy.

var _arbor_player: PlayerController = null
var _arbor_prompted: bool = false


func _build_procedural() -> void:
	setup_environment(
		Color(0.45, 0.55, 0.7),
		Color(0.8, 0.78, 0.6),
		0.95
	)
	make_ground(Vector2(46, 80), Color(0.42, 0.46, 0.34))

	# Signposts at the three corridor mouths (the base, z > 0, is open so you
	# can walk to any of them and choose).
	make_floating_label("危险小路 Danger →", Vector3(-12, 2.6, -1), Color(0.6, 0.7, 0.95))
	make_floating_label("艰难正路 Difficulty", Vector3(0, 2.6, -1), Color(0.95, 0.95, 0.8))
	make_floating_label("← Destruction", Vector3(12, 2.6, -1), Color(0.95, 0.7, 0.5))

	# Dividing walls between the three corridors (only for z < 0, so the base
	# plaza stays open for the choice).
	make_block(Vector3(1, 4, 34), Color(0.4, 0.42, 0.36), Vector3(-6, 2, -17))
	make_block(Vector3(1, 4, 34), Color(0.4, 0.42, 0.36), Vector3(6, 2, -17))
	# Outer walls.
	make_block(Vector3(1, 4, 34), Color(0.36, 0.38, 0.32), Vector3(-18, 2, -17))
	make_block(Vector3(1, 4, 34), Color(0.36, 0.38, 0.32), Vector3(18, 2, -17))

	# Left: Danger — a dark dead end that breeds deception.
	make_block(Vector3(11, 4, 1), Color(0.3, 0.34, 0.4), Vector3(-12, 2, -26))
	var _cb1 := func(_b):
		SpiritualStateManager.apply_effects({"deception": 10, "discernment": -4})
		EventBus.toast("危险小路把终点藏在荆棘与阴影里。回到真实的路上。")
	make_trigger(Vector3(-12, 1.5, -22), Vector3(10, 4, 2), _cb1, true)

	# Right: Destruction — wide, comfortable, ending in a sudden drop.
	make_block(Vector3(11, 4, 1), Color(0.5, 0.4, 0.34), Vector3(12, 2, -26))
	var _cb2 := func(_b):
		SpiritualStateManager.apply_effects({"despair": 12, "weariness": 8})
		EventBus.toast("毁灭之路一直宽阔，直到它在脚下断裂。踉跄也要回到真理。")
	make_trigger(Vector3(12, 1.5, -22), Vector3(10, 4, 2), _cb2, true)

	# Middle: the true, steep way — slow going, with a tempting rest arbor.
	_add_steep_zone(Vector3(0, 1, -14), Vector3(10, 2, 22))
	_build_rest_arbor(Vector3(0, 0, -22))
	_decorate_paths()

	make_distant_light(Vector3(0, 7, -44), Color(1.0, 0.95, 0.7))
	make_floating_label("山顶 The Summit", Vector3(0, 4, -36), Color(1, 0.97, 0.8))

	make_wayside_chapel(Vector3(-3.5, 0, -6), "hill", {"perseverance": 8, "hope": 4, "weariness": -4}, "A true chapel at the climb — not the arbor's false ease. You rise stronger.")

	spawn_player(Vector3(0, 1, 9))

	var _cb3 := func(_b):
		GameState.set_flag("reached_summit", true)
		QuestManager.update_quest_progress("climb_hill")
		EventBus.toast("你越过山顶，气喘却蒙保守。美宫的光在前方亮起。")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -33), Vector3(10, 4, 2), _cb3, false)


# Make the three ways read at a glance: Danger looks ominous, Destruction looks
# the most inviting (and is the trap), Difficulty is plain but lit by the summit.
func _decorate_paths() -> void:
	# Left — Danger: cold, dim, thorned. A discerning pilgrim feels the wrongness.
	var dlight := OmniLight3D.new()
	dlight.position = Vector3(-12, 3, -14)
	dlight.light_color = Color(0.35, 0.4, 0.6)
	dlight.light_energy = 0.5
	dlight.omni_range = 16.0
	add_child(dlight)
	make_decor(Vector3(11, 0.05, 30), Color(0.12, 0.12, 0.16), Vector3(-12, 0.06, -16))
	for tz in [-8, -14, -20]:
		make_decor(Vector3(0.3, 1.6, 0.3), Color(0.08, 0.1, 0.09), Vector3(-12 + randf_range(-2.0, 2.0), 0.8, tz))
	make_floating_label("(shadow and thorn)", Vector3(-12, 1.8, -16), Color(0.5, 0.55, 0.7))

	# Right — Destruction: warm, wide, golden — the most appealing path, and false.
	for lz in [-8, -18]:
		var wl := OmniLight3D.new()
		wl.position = Vector3(12, 3.5, lz)
		wl.light_color = Color(1.0, 0.82, 0.45)
		wl.light_energy = 3.2
		wl.omni_range = 18.0
		add_child(wl)
	make_decor(Vector3(11, 0.05, 30), Color(0.7, 0.55, 0.3), Vector3(12, 0.07, -16), 0.5)
	make_floating_label("(easy and broad)", Vector3(12, 1.8, -12), Color(1.0, 0.85, 0.55))
	# ...but a sudden black drop waits at its end.
	make_decor(Vector3(10, 0.4, 5), Color(0.02, 0.02, 0.03), Vector3(12, -0.18, -25))
	make_floating_label("!", Vector3(12, 1.4, -25), Color(0.95, 0.3, 0.25))

	# Middle — Difficulty: plain stone, but guiding motes lead up toward the summit.
	for mz in [-10, -18, -26]:
		make_decor(Vector3(0.25, 0.25, 0.25), Color(1.0, 0.95, 0.7), Vector3(0, 1.4, mz), 2.5)


func _add_steep_zone(pos: Vector3, size: Vector3) -> void:
	var z := MudZone.new()
	add_child(z)
	z.setup(size, false, Color(0.5, 0.45, 0.38, 0.45))  # rocky, not muddy
	z.position = pos
	z.movement_multiplier = 0.6
	z.effects_per_tick = {"weariness": 1, "perseverance": 1}


func _build_rest_arbor(pos: Vector3) -> void:
	make_decor(Vector3(3, 0.3, 3), Color(0.4, 0.5, 0.35), pos + Vector3(0, 0.15, 0))
	make_floating_label("歇息亭 Rest Arbor", pos + Vector3(0, 1.6, 0), Color(0.8, 0.85, 0.7))
	var arbor := Area3D.new()
	arbor.collision_layer = 0
	arbor.collision_mask = 1
	arbor.monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 3)
	col.shape = box
	arbor.add_child(col)
	arbor.position = pos + Vector3(0, 1, 0)
	arbor.body_entered.connect(_on_arbor_enter)
	arbor.body_exited.connect(_on_arbor_exit)
	add_child(arbor)


func _on_arbor_enter(body: Node) -> void:
	if body is PlayerController:
		_arbor_player = body
		if not _arbor_prompted and not DialogueManager.is_active():
			_arbor_prompted = true
			DialogueManager.start_dialogue("rest_arbor")


func _on_arbor_exit(body: Node) -> void:
	if body == _arbor_player:
		_arbor_player = null
