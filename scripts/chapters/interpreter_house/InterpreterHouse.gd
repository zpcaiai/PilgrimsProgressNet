extends ChapterBase
class_name InterpreterHouse
## Chapter 6. A safe, candlelit hall of symbolic rooms. Each lesson sharpens an
## inner sense. Speak with the Interpreter, consider a room, then leave by the
## far door.


func _build_chapter() -> void:
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
	_lesson(Vector3(-6, 0, -8), "The Lamp", "The lamp fed in secret keeps burning when public strength is gone.", {"faith": 5, "perseverance": 4})
	_lesson(Vector3(6, 0, -8), "The Dust", "Dry command can expose the dust; only living water settles the heart.", {"humility": 5, "discernment": 4})
	_lesson(Vector3(0, 0, -16), "The Patient Man", "Patience waits for the promised portion and is not robbed by haste.", {"watchfulness": 5, "hope": 4})

	make_distant_light(Vector3(0, 4, -30))
	spawn_player(Vector3(0, 1, 8))

	make_trigger(Vector3(0, 1.5, -24), Vector3(20, 4, 2), func(_b):
		if not GameState.has_flag("saw_interpreter_lesson"):
			EventBus.toast("Do not hurry past mercy's instruction. Consider at least one room.")
			return
		GameState.set_flag("left_interpreter", true)
		QuestManager.update_quest_progress("visit_interpreter")
		EventBus.toast("You step out with clearer sight, and the hill waits ahead.")
		_advance_after_delay()
	, false)


func _lesson(pos: Vector3, title: String, text: String, effects: Dictionary) -> void:
	make_floating_label(title, pos + Vector3(0, 2.2, 0), Color(0.95, 0.85, 0.6))
	make_interactable(pos, "Consider: " + title,
		func(_p):
			SpiritualStateManager.apply_effects(effects)
			GameState.set_flag("saw_interpreter_lesson", true)
			QuestManager.update_quest_progress("visit_interpreter")
			EventBus.toast(text)
		, null, Color(0.7, 0.6, 0.4), 0.6, 1.4, true)
