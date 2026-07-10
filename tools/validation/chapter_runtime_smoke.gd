extends Node
## Instantiates every shipped chapter through the real ChapterManager and checks
## the shared runtime contract: player, collision, chapel, and a closing path.

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _fail(chapter_id: String, message: String) -> void:
	_failures.append("[%s] %s" % [chapter_id, message])


func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count


func _count_exit_triggers(node: Node) -> int:
	var count := 1 if node is ChapterExitTrigger else 0
	for child in node.get_children():
		count += _count_exit_triggers(child)
	return count


func _count_journey_reviews(node: Node) -> int:
	var count := 1 if node is JourneyReviewScreen else 0
	for child in node.get_children():
		count += _count_journey_reviews(child)
	return count


func _run() -> void:
	var event_bus := get_node("/root/EventBus")
	var game_state := get_node("/root/GameState")
	var spiritual_state := get_node("/root/SpiritualStateManager")
	var quest_manager := get_node("/root/QuestManager")
	var chapter_manager := get_node("/root/ChapterManager")
	event_bus.clear_player_locks()
	event_bus.lock_player("smoke_a")
	event_bus.lock_player("smoke_b")
	event_bus.unlock_player("smoke_a")
	if not event_bus.is_player_locked():
		_fail("shared", "closing one modal unlocked another active modal")
	event_bus.unlock_player("smoke_b")
	if event_bus.is_player_locked():
		_fail("shared", "modal lock remained after every owner released it")
	game_state.reset_for_new_game()
	quest_manager.reset_for_new_game()
	quest_manager.start_quest("cross_wilderness")
	for flag in ["obstinate_left", "spoke_with_pliable", "fixed_eyes_on_light"]:
		game_state.set_flag(flag, true)
	if not quest_manager.is_quest_completed("cross_wilderness"):
		_fail("shared", "quest did not close immediately after its flags changed")
	var world := Node3D.new()
	add_child(world)
	chapter_manager.set_world_root(world)
	for chapter_id in chapter_manager.CANONICAL_ROUTE:
		event_bus.clear_player_locks()
		game_state.reset_for_new_game()
		spiritual_state.reset_for_new_game()
		quest_manager.reset_for_new_game()
		var chapter_data: Dictionary = chapter_manager.load_chapter_data(String(chapter_id))
		for flag in chapter_data.get("required_flags", []):
			game_state.set_flag(String(flag), true)
		chapter_manager.start_chapter(String(chapter_id))
		await get_tree().process_frame
		await get_tree().process_frame
		var scene: Node = chapter_manager.get_current_scene_instance()
		if not is_instance_valid(scene):
			_fail(String(chapter_id), "chapter scene did not instantiate")
			continue
		if not (scene is ChapterBase):
			_fail(String(chapter_id), "scene root is not ChapterBase")
			continue
		var chapter := scene as ChapterBase
		if not is_instance_valid(chapter.player):
			_fail(String(chapter_id), "player was not created")
		elif _count_type(chapter.player, "CollisionShape3D") == 0:
			_fail(String(chapter_id), "player has no collision shape")
		if int(chapter.get("_chapels_built")) < 1:
			_fail(String(chapter_id), "chapter has no cross-bearing chapel")
		if String(chapter_id) == "celestial_city":
			if _count_journey_reviews(chapter) == 0:
				_fail(String(chapter_id), "final journey review is missing")
		elif bool(chapter.get("_used_glb")) and _count_exit_triggers(chapter) == 0:
			_fail(String(chapter_id), "chapter has no bound exit trigger")
		if _count_type(chapter, "StaticBody3D") == 0:
			_fail(String(chapter_id), "chapter has no solid world collision")
		print("  %-24s runtime contract OK" % String(chapter_id))

	if is_instance_valid(chapter_manager.get_current_scene_instance()):
		chapter_manager.get_current_scene_instance().queue_free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("CHAPTER RUNTIME SMOKE PASSED: all 16 chapters are structurally playable")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("CHAPTER RUNTIME SMOKE FAILED: %d issue(s)" % _failures.size())
	get_tree().quit(1)
