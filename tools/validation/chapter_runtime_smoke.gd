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


func _count_mud_systems(node: Node) -> int:
	var count := 1 if node is MudSystem else 0
	for child in node.get_children():
		count += _count_mud_systems(child)
	return count


func _validate_npc_auto_dialogue(node: Node, chapter_id: String) -> void:
	if node is Interactable and node.is_in_group("auto_dialogue_person"):
		var person := node as Interactable
		if not person.has_auto_dialogue():
			_fail(chapter_id, "person %s has no automatic approach trigger" % String(person.name))
	if node is NPCInteractable:
		var npc := node as NPCInteractable
		if npc.dialogue_id != "" and not npc.has_auto_dialogue():
			_fail(chapter_id, "NPC %s has dialogue but no automatic approach trigger" % npc.npc_name)
	if node is PilgrimFamily and node.find_child("AutoDialogueProximity", true, false) == null:
		_fail(chapter_id, "the pilgrim's family has no automatic approach trigger")
	if node is GiantDespair and node.find_child("AutoDialogueProximity", true, false) == null:
		_fail(chapter_id, "Giant Despair has no automatic approach trigger")
	for child in node.get_children():
		_validate_npc_auto_dialogue(child, chapter_id)


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
	# Node-level dialogue outcomes use both `flags` and `set_flags` in shipped
	# data. Reaching Goodwill's final line must open the gate before dialogue ends.
	game_state.reset_for_new_game()
	DialogueManager.start_dialogue("wicket_gate_knock")
	DialogueManager.select_choice("knock")
	if not game_state.has_flag("passed_wicket_gate"):
		_fail("shared", "node-level dialogue flags did not open the Wicket Gate")
	DialogueManager.end_dialogue()
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
		if String(chapter_id) == "wicket_gate" and int(chapter.get("_chapels_built")) != 0:
			_fail(String(chapter_id), "Wicket Gate must not build a chapel over its exit path")
		elif String(chapter_id) != "wicket_gate" and int(chapter.get("_chapels_built")) < 1:
			_fail(String(chapter_id), "chapter has no cross-bearing chapel")
		if String(chapter_id) == "celestial_city":
			if _count_journey_reviews(chapter) == 0:
				_fail(String(chapter_id), "final journey review is missing")
		elif bool(chapter.get("_used_glb")) and _count_exit_triggers(chapter) == 0:
			_fail(String(chapter_id), "chapter has no bound exit trigger")
		if _count_type(chapter, "StaticBody3D") == 0:
			_fail(String(chapter_id), "chapter has no solid world collision")
		_validate_npc_auto_dialogue(chapter, String(chapter_id))
		if String(chapter_id) == "city_of_destruction" and is_instance_valid(chapter.player):
			var evangelist := chapter.find_child("Evangelist", true, false) as Interactable
			if evangelist == null:
				_fail(String(chapter_id), "Evangelist NPC is missing")
			elif evangelist.get_auto_dialogue_id() != "evangelist_first_call":
				_fail(String(chapter_id), "Evangelist automatic dialogue is not configured")
			else:
				chapter.player.teleport(evangelist.global_position + Vector3(4.2, 1.0, 0))
				await get_tree().physics_frame
				await get_tree().physics_frame
				chapter.player.teleport(evangelist.global_position + Vector3(1.4, 1.0, 0))
				await get_tree().physics_frame
				await get_tree().create_timer(0.4).timeout
				var history := DialogueManager.get_history_summary()
				if not bool(history.get("active", false)) or String(history.get("dialogue", "")) != "evangelist_first_call":
					_fail(String(chapter_id), "approaching Evangelist did not start his dialogue")
				var facing_error := absf(wrapf(evangelist.global_rotation.y - PI * 0.5, -PI, PI))
				if facing_error > 0.2:
					_fail(String(chapter_id), "Evangelist did not turn toward the approaching player")
				DialogueManager.end_dialogue()
				await get_tree().process_frame
		if String(chapter_id) == "slough_of_despond":
			var deep_zones := 0
			var deepest_sink := 0.0
			var deepest_zone: MudZone = null
			for zone in get_tree().get_nodes_in_group("mud_zone"):
				if zone is MudZone and chapter.is_ancestor_of(zone):
					var mud := zone as MudZone
					if mud.is_deep:
						deep_zones += 1
						if mud.center_sink_depth > deepest_sink:
							deepest_sink = mud.center_sink_depth
							deepest_zone = mud
			if deep_zones < 2:
				_fail(String(chapter_id), "deep mire zones are missing")
			if deepest_sink < 1.0:
				_fail(String(chapter_id), "deep mire cannot submerge the player enough to struggle")
			if _count_mud_systems(chapter) == 0:
				_fail(String(chapter_id), "mud sinking and struggle system is missing")
			if is_instance_valid(chapter.player) and not chapter.player.has_method("set_mud_struggling"):
				_fail(String(chapter_id), "player has no mire struggle pose control")
			if is_instance_valid(deepest_zone) and is_instance_valid(chapter.player):
				var deep_center := deepest_zone.global_position
				chapter.player.teleport(Vector3(deep_center.x, 1.0, deep_center.z))
				await get_tree().physics_frame
				await get_tree().physics_frame
				await get_tree().physics_frame
				await get_tree().process_frame
				if not deepest_zone.is_occupied():
					_fail(String(chapter_id), "deep mire did not detect the player at its centre")
				elif deepest_zone.current_sink_depth() < 1.0:
					_fail(String(chapter_id), "deep mire centre did not apply full submersion")
				if not chapter.player.is_mud_struggling():
					_fail(String(chapter_id), "deep mire did not activate the struggle pose")
		if String(chapter_id) == "wicket_gate":
			var gate_door := chapter.find_child("PROP_GateDoor", true, false) as Node3D
			var closed_door_y := gate_door.position.y if is_instance_valid(gate_door) else 0.0
			DialogueManager.start_dialogue("wicket_gate_knock")
			DialogueManager.select_choice("knock")
			await get_tree().create_timer(0.8).timeout
			await get_tree().process_frame
			if not (chapter as WicketGate).is_gate_open():
				_fail(String(chapter_id), "passed flag did not visibly open the gate")
			if not is_instance_valid(gate_door):
				_fail(String(chapter_id), "gate door visual is missing")
			elif gate_door.position.y < closed_door_y + 4.0:
				_fail(String(chapter_id), "gate door did not rise clear of the passage")
			DialogueManager.end_dialogue()
			await get_tree().process_frame
			if is_instance_valid(chapter.player) and chapter.player.global_position.z > -9.8:
				_fail(String(chapter_id), "Goodwill did not pull the player inside the open gate")
			if is_instance_valid(chapter.player):
				chapter.player.teleport(Vector3(0, 1, -6.8))
				await get_tree().physics_frame
				var blocked := chapter.player.move_and_collide(Vector3(0, 0, -10.0), true)
				if blocked != null:
					var blocker := blocked.get_collider()
					var blocker_name := str(blocker)
					if blocker is Node:
						var ancestry: Array[String] = []
						var cursor := blocker as Node
						while cursor != null and cursor != chapter:
							ancestry.append("%s<%s>" % [String(cursor.name), cursor.get_class()])
							cursor = cursor.get_parent()
						blocker_name = " -> ".join(ancestry)
					_fail(String(chapter_id), "open gate path is blocked by %s" % blocker_name)
			game_state.set_flag("scripture_wicket_gate", true)
			var exit_triggers := chapter.find_children("*", "ChapterExitTrigger", true, false)
			if exit_triggers.is_empty():
				_fail(String(chapter_id), "exit portal trigger is missing")
			var exit_was_overlapped := false
			chapter.player.teleport(Vector3(0, 1, -9.2))
			await get_tree().physics_frame
			await get_tree().physics_frame
			for _step in range(32):
				chapter.player.move_and_collide(Vector3(0, 0, -0.25))
				await get_tree().physics_frame
				if not exit_triggers.is_empty() and is_instance_valid(exit_triggers[0]):
					exit_was_overlapped = exit_was_overlapped or chapter.player in (exit_triggers[0] as Area3D).get_overlapping_bodies()
			await get_tree().create_timer(0.8).timeout
			if String(chapter_manager.current_chapter_id) != "cross_and_tomb":
				var exit_detail := "missing"
				if not exit_triggers.is_empty() and is_instance_valid(exit_triggers[0]):
					var exit_area := exit_triggers[0] as Area3D
					exit_detail = "pos=%s overlaps=%s seen=%s fired=%s gate_open=%s" % [
						str(exit_area.global_position),
						str(exit_area.get_overlapping_bodies().map(func(body): return String(body.name))),
						exit_was_overlapped,
						exit_area.get("_fired"),
						exit_area.get("_gate_open")
					]
				_fail(String(chapter_id), "exit portal did not advance to cross_and_tomb; player=%s %s" % [
					str(chapter.player.global_position), exit_detail])
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
