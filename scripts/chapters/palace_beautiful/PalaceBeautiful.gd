extends ChapterBase
class_name PalaceBeautiful
## Chapter 8. A safe hub on the hilltop. Rest, speak with Watchful, and take up
## the armour of faith before descending into the valley.


func _build_chapter() -> void:
	setup_environment(
		Color(0.25, 0.3, 0.5),
		Color(0.9, 0.7, 0.45),
		0.9
	)
	make_ground(Vector2(30, 50), Color(0.5, 0.46, 0.4))

	# Palace walls and warm windows.
	make_block(Vector3(1, 6, 36), Color(0.55, 0.5, 0.44), Vector3(-10, 3, -8))
	make_block(Vector3(1, 6, 36), Color(0.55, 0.5, 0.44), Vector3(10, 3, -8))
	make_block(Vector3(20, 6, 1), Color(0.5, 0.46, 0.4), Vector3(0, 3, -24))
	for z in [0, -8, -16]:
		var win := OmniLight3D.new()
		win.position = Vector3(0, 4, z)
		win.light_color = Color(1.0, 0.85, 0.55)
		win.light_energy = 2.0
		win.omni_range = 14.0
		add_child(win)

	# A place to rest.
	var rest := SafeStone.new()
	add_child(rest)
	rest.setup(2.2)
	rest.position = Vector3(-4, 0, -6)
	make_floating_label("Rest", Vector3(-4, 1.8, -6), Color(0.85, 0.9, 0.7))

	make_npc("Watchful", Vector3(0, 0, -12), Color(0.85, 0.82, 0.65), "palace_welcome")

	# Armour stand decor.
	make_decor(Vector3(0.8, 1.6, 0.4), Color(0.7, 0.72, 0.8), Vector3(4, 0.8, -12), 0.3)

	# The library — records of pilgrims who walked before you.
	make_decor(Vector3(3, 2, 0.6), Color(0.4, 0.3, 0.24), Vector3(-7, 1, -14))
	make_floating_label("Library", Vector3(-7, 2.4, -14), Color(0.85, 0.82, 0.6))
	var _cb1 := func(_p):
		SpiritualStateManager.apply_effects({"discernment": 6, "faith": 4, "hope": 4})
		EventBus.toast("Account after account says the same thing: grace kept them, and grace can keep you.")
	make_interactable(Vector3(-7, 0, -12.6), "Read the records of pilgrims who endured",
		_cb1, null, Color(0.6, 0.5, 0.4), 0.3, 1.4, true)

	make_distant_label_to_valley()
	spawn_player(Vector3(0, 1, 8))

	var _cb2 := func(_b):
		if not GameState.has_flag("took_armour"):
			EventBus.toast("The valley will accuse you. Speak with Watchful and take up the armour first.")
			return
		GameState.set_flag("left_palace", true)
		QuestManager.update_quest_progress("rest_palace")
		EventBus.toast("Armed with faith and warned by love, you descend toward the valley.")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -22), Vector3(16, 5, 2), _cb2, false)


func make_distant_label_to_valley() -> void:
	make_floating_label("Down to the Valley of Humiliation", Vector3(0, 3.4, -20), Color(0.8, 0.78, 0.85))
