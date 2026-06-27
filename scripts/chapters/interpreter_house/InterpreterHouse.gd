extends GlbChapter
class_name InterpreterHouse
## Chapter 6. A safe, candlelit hall of symbolic rooms. Each lesson sharpens an
## inner sense. Speak with the Interpreter, consider a room, then leave by the
## far door. A symbol lights for each lesson considered; two are needed to leave.

var _lessons_seen: int = 0


func _build_procedural() -> void:
	setup_environment(
		Color(0.1, 0.09, 0.12),
		Color(0.3, 0.22, 0.12),
		0.5
	)
	make_ground(Vector2(24, 50), Color(0.26, 0.2, 0.16))
	# Walls to make it feel like a hall.
	make_block(Vector3(1, 5, 50), Color(0.2, 0.16, 0.13), Vector3(-11, 2.5, -10))
	make_block(Vector3(1, 5, 50), Color(0.2, 0.16, 0.13), Vector3(11, 2.5, -10))

	# Warm candle lights.
	for z in [2, -8, -18]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 4, z)
		lamp.light_color = Color(1.0, 0.8, 0.5)
		lamp.light_energy = 2.2
		lamp.omni_range = 12.0
		add_child(lamp)

	make_npc("The Interpreter", Vector3(0, 0, 2), Color(0.85, 0.8, 0.6), "interpreter_welcome")

	# Symbolic rooms — each is a one-shot lesson.
	_lesson(Vector3(-6, 0, -8), "灯 The Lamp", "暗中得油的灯，在外面的力量耗尽时仍会燃烧。", {"faith": 5, "perseverance": 4})
	_lesson(Vector3(6, 0, -8), "尘土 The Dust", "干硬的命令能扬起尘土；只有活水能安定人心。", {"humility": 5, "discernment": 4})
	_lesson(Vector3(0, 0, -16), "忍耐的人 The Patient Man", "忍耐等候所应许的份，不让急躁夺走心。", {"watchfulness": 5, "hope": 4})

	make_distant_light(Vector3(0, 4, -30))
	spawn_player(Vector3(0, 1, 8))

	var _cb1 := func(_b):
		if _lessons_seen < 2:
			EventBus.toast("不要匆匆掠过怜悯的教导。至少默想两个房间。")
			return
		GameState.set_flag("left_interpreter", true)
		QuestManager.update_quest_progress("visit_interpreter")
		EventBus.toast("你带着更清楚的眼光走出门去；艰难山在前方等候。")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -24), Vector3(20, 4, 2), _cb1, false)


func _lesson(pos: Vector3, title: String, text: String, effects: Dictionary) -> void:
	make_floating_label(title, pos + Vector3(0, 2.2, 0), Color(0.95, 0.85, 0.6))
	# An unlit symbol that kindles when the lesson is considered.
	var symbol := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.38
	sm.height = 0.76
	symbol.mesh = sm
	symbol.position = pos + Vector3(0, 1.3, 0)
	symbol.material_override = make_material(Color(0.3, 0.26, 0.2))
	add_child(symbol)
	var _cb2 := func(_p):
		SpiritualStateManager.apply_effects(effects)
		_lessons_seen += 1
		GameState.set_flag("saw_interpreter_lesson", true)
		QuestManager.update_quest_progress("visit_interpreter")
		var lit := make_material(Color(1.0, 0.9, 0.6))
		lit.emission_enabled = true
		lit.emission = Color(1.0, 0.85, 0.55)
		lit.emission_energy_multiplier = 2.5
		symbol.material_override = lit
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.88, 0.6)
		lamp.light_energy = 2.0
		lamp.omni_range = 6.0
		symbol.add_child(lamp)
		if _lessons_seen >= 3:
			SpiritualStateManager.apply_effects({"discernment": 5, "watchfulness": 5, "hope": 3})
			GameState.set_flag("interpreter_full", true)
			EventBus.toast("三个房间都默想过了。安静的洞察落在心里：日后在路上，你会认得灯、尘土与忍耐之道。 " + text)
		else:
			EventBus.toast("（已默想 %d/2）%s" % [_lessons_seen, text])
	make_interactable(pos, "默想：" + title,
		_cb2, null, Color(0.7, 0.6, 0.4), 0.6, 1.4, true)
