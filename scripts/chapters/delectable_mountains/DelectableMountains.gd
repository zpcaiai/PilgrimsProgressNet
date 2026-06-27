extends GlbChapter
class_name DelectableMountains
## Chapter 13. A bright, restful height. The Shepherds give counsel and let you
## see the Celestial City through their glass. Rest, then go on.


func _build_procedural() -> void:
	setup_environment(
		Color(0.5, 0.7, 0.95),
		Color(0.95, 0.9, 0.7),
		1.1
	)
	make_ground(Vector2(40, 55), Color(0.4, 0.62, 0.4))
	# Rolling hills.
	make_block(Vector3(10, 3, 10), Color(0.42, 0.6, 0.4), Vector3(-12, 1, -16))
	make_block(Vector3(12, 4, 10), Color(0.44, 0.62, 0.42), Vector3(12, 1.5, -18))

	var rest := SafeStone.new()
	add_child(rest)
	rest.setup(2.4)
	rest.position = Vector3(-4, 0, -4)
	make_floating_label("歇息 Rest", Vector3(-4, 1.8, -4), Color(0.85, 0.9, 0.7))

	make_npc("The Shepherds", Vector3(0, 0, -10), Color(0.8, 0.78, 0.6), "shepherds_counsel")

	# The viewing glass — look toward the City.
	var _cb1 := func(_p):
		GameState.set_flag("saw_celestial_city", true)
		QuestManager.update_quest_progress("visit_mountains")
		SpiritualStateManager.apply_effects({"hope": 12, "faith": 6})
		EventBus.toast("透过望远镜：远处城门发光。那城真实，道路并非徒然。")
	make_interactable(Vector3(4, 0, -10), "透过望远镜观看 (Look)",
		_cb1, null, Color(0.7, 0.8, 0.9), 0.5, 1.4, true)

	# The City, faint and golden, far off.
	make_distant_light(Vector3(0, 8, -46), Color(1.0, 0.95, 0.7))
	make_floating_label("天城 The Celestial City", Vector3(0, 5, -40), Color(1.0, 0.96, 0.75))

	make_wayside_chapel(Vector3(12, 0, -6), "mountains", {"hope": 8, "faith": 4}, "高处有牧人的祷告室；你祷告，那城似乎更近了。")

	spawn_player(Vector3(0, 1, 10))

	var _cb2 := func(_b):
		if not GameState.has_flag("saw_celestial_city"):
			EventBus.toast("下山前，先领受牧人的劝告，并透过望远镜观看。")
			return
		GameState.set_flag("left_mountains", true)
		QuestManager.update_quest_progress("visit_mountains")
		EventBus.toast("你得了鼓励，也受了警戒，便下山走向迷睡之地。")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -26), Vector3(20, 4, 2), _cb2, false)
