extends GlbChapter
class_name EnchantedGround
## Chapter 14. The air itself presses a heavy sleep on you. Lingering lets the
## drowse take you (and sets you back); keep moving, and let Hopeful's voice
## rouse you. Reach the far edge awake.


func _build_procedural() -> void:
	setup_environment(
		Color(0.25, 0.2, 0.3),
		Color(0.5, 0.4, 0.5),
		0.6,
		true, Color(0.4, 0.3, 0.45), 0.04
	)
	make_ground(Vector2(26, 80), Color(0.3, 0.28, 0.34))
	make_block(Vector3(1, 4, 70), Color(0.24, 0.22, 0.28), Vector3(-10, 2, -20))
	make_block(Vector3(1, 4, 70), Color(0.24, 0.22, 0.28), Vector3(10, 2, -20))

	make_wayside_chapel(Vector3(-8, 0, -30), "enchanted", {"watchfulness": 8, "weariness": -6, "hope": 3}, "地边有一座唤醒人的小堂；它的光很响亮，睡意松开了手。")

	spawn_player(Vector3(0, 1, 14))
	# Ensure Hopeful is present to rouse the pilgrim (joined back at Vanity Fair).
	if companion == null and not GameState.has_companion("hopeful"):
		GameState.add_companion("hopeful")
		spawn_companion("Hopeful", Color(0.55, 0.8, 0.7))

	# The drowse field covers the middle of the ground.
	var field := SleepField.new()
	add_child(field)
	field.setup(Vector3(18, 3, 48), Vector3(0, 1, 12))
	field.position = Vector3(0, 1.5, -12)

	# Soft seats that tempt you to lie down (flavour + warning).
	_couch(Vector3(-5, 0, -6))
	_couch(Vector3(5, 0, -22))

	make_distant_light(Vector3(0, 5, -48), Color(0.8, 0.85, 0.9))
	make_floating_label("让渴慕保持清醒", Vector3(0, 3, -34), Color(0.85, 0.8, 0.7))

	var _cb1 := func(_b):
		GameState.set_flag("crossed_enchanted", true)
		QuestManager.update_quest_progress("cross_enchanted")
		EventBus.toast("你踉跄着清醒走出；盼望仍在把那城说进你的记忆里。")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -42), Vector3(18, 4, 2), _cb1, false)


func _couch(pos: Vector3) -> void:
	make_decor(Vector3(2.5, 0.5, 1.4), Color(0.45, 0.35, 0.5), pos + Vector3(0, 0.25, 0), 0.2)
	var _cb2 := func(_p):
		SpiritualStateManager.apply_effects({"weariness": 12, "watchfulness": -8})
		EventBus.toast("你陷入舒适，渴慕渐暗。盼望在睡意得胜前把你拉起。")
	make_interactable(pos, "软榻诱你不再在意 (Rest?)",
		_cb2, null, Color(0.4, 0.3, 0.45), 0.2, 1.3, false)
