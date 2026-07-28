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

	# The Shepherds now EXAMINE the pilgrim before they lend the glass: they ask
	# him to name the lie he was told in the Valley and the truth that answered
	# it. The correct answers are only offered to a player who actually stood
	# against the accuser. Previously this was a 3-node one-way warning.
	var shepherd_dialogue := "shepherds_examination"
	if not DialogueManager.has_dialogue(shepherd_dialogue):
		shepherd_dialogue = "shepherds_counsel"
	make_npc("The Shepherds", Vector3(0, 0, -10), Color(0.8, 0.78, 0.6), shepherd_dialogue)

	# The viewing glass. This used to be an instant stat buff and a toast: the
	# most hopeful moment in the game, delivered as a number. It is now a
	# REVEAL — the camera leaves the pilgrim and travels to the City itself
	# (using the chapter's authored CAM_ marker), holds on it, and comes back.
	var _cb1 := func(_p):
		_look_through_glass()
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


## The telescope, as a revelation rather than a buff.
##
## The chapter's whole emotional function is "you are shown, for the first time
## since the Cross, that the City is real". Delivering that as `hope +12` and a
## line of text wasted it. The camera now travels to the City marker, holds
## while the pilgrim (and the player) look at it, and returns.
func _look_through_glass() -> void:
	if GameState.has_flag("saw_celestial_city"):
		EventBus.toast("你又看了一眼。那城还在那里。")
		return
	GameState.set_flag("saw_celestial_city", true)
	QuestManager.update_quest_progress("visit_mountains")
	SpiritualStateManager.apply_effects({"hope": 12, "faith": 6})
	# A shepherd who examined you and was satisfied lends you a steadier hand.
	if GameState.has_flag("shepherd_exam_passed"):
		SpiritualStateManager.apply_effects({"discernment": 5, "watchfulness": 4})
	EventBus.toast("透过望远镜：远处城门发光。那城真实，道路并非徒然。")
	# Prefer an authored viewpoint marker; fall back to framing the distant city
	# light this chapter always builds at (0, 8, -46).
	if ChapterCamera.shot("CelestialCity", 4.4, false):
		return
	if ChapterCamera.shot("SummitReveal", 4.4, false):
		return
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("push_cinematic"):
		var from := Vector3(0, 9.0, -14.0)
		var xf := Transform3D(Basis(), from).looking_at(Vector3(0, 8, -46), Vector3.UP)
		p.call("push_cinematic", xf, 4.4)
