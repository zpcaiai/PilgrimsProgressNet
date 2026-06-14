extends ChapterBase
class_name WildernessRoad
## Chapter 2. The narrow road out of the city. Obstinate gives one last push to
## turn back; Pliable walks ahead full of shallow excitement. Reach the swamp.


func _build_chapter() -> void:
	setup_environment(
		Color(0.35, 0.4, 0.5),
		Color(0.6, 0.55, 0.45),
		0.8
	)
	# A long narrow road (forward = -Z).
	make_ground(Vector2(12, 80), Color(0.4, 0.36, 0.3))
	# Rocks lining the road.
	for i in range(6):
		var z := 4.0 - i * 10.0
		make_block(Vector3(2, 1.5, 2), Color(0.45, 0.43, 0.4), Vector3(-7, 0.75, z))
		make_block(Vector3(2, 1.2, 2), Color(0.42, 0.4, 0.38), Vector3(7, 0.6, z - 4))

	# The doomed city behind, the light ahead.
	make_decor(Vector3(30, 10, 1), Color(0.3, 0.12, 0.1), Vector3(0, 5, 16), 0.6)
	make_distant_light(Vector3(0, 5, -42))
	make_floating_label("The ground will test the heart", Vector3(0, 3.2, -30), Color(0.8, 0.85, 0.7))

	make_npc("Obstinate", Vector3(2.5, 0, -6), Color(0.45, 0.4, 0.35), "obstinate_road")
	make_npc("Pliable", Vector3(-2.5, 0, -16), Color(0.6, 0.7, 0.5), "pliable_doubting")

	spawn_player(Vector3(0, 1, 8))

	make_trigger(Vector3(0, 1.5, -40), Vector3(12, 4, 2), func(_b):
		GameState.set_flag("entered_slough", true)
		QuestManager.update_quest_progress("cross_wilderness")
		EventBus.toast("The ground softens, and the first deep discouragement opens underfoot.")
		_advance_after_delay()
	, false)
