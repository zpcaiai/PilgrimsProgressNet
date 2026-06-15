extends ChapterBase
class_name DoubtingCastle
## Chapter 12. Captured by Giant Despair and shut in a cell. Despair presses on
## you while the Giant prowls. The key called Promise can open any door of this
## castle — find it (or remember you carry it) and escape.

var _aura: float = 0.0
var _vignette: DarkVignette = null


func _build_chapter() -> void:
	setup_environment(
		Color(0.05, 0.06, 0.09),
		Color(0.12, 0.12, 0.16),
		0.3
	)
	make_ground(Vector2(40, 50), Color(0.18, 0.18, 0.22))

	# A cell: three walls around the spawn, with a door gap on the -Z side.
	make_block(Vector3(8, 5, 1), Color(0.25, 0.25, 0.3), Vector3(0, 2.5, 4))     # behind
	make_block(Vector3(1, 5, 9), Color(0.25, 0.25, 0.3), Vector3(-4, 2.5, 0))    # left
	make_block(Vector3(1, 5, 9), Color(0.25, 0.25, 0.3), Vector3(4, 2.5, 0))     # right
	# Door pillars (the gap between them is the locked door).
	make_block(Vector3(1.5, 5, 1), Color(0.3, 0.3, 0.34), Vector3(-2.6, 2.5, -4))
	make_block(Vector3(1.5, 5, 1), Color(0.3, 0.3, 0.34), Vector3(2.6, 2.5, -4))
	var door := make_block(Vector3(3.2, 5, 0.5), Color(0.2, 0.18, 0.16), Vector3(0, 2.5, -4))

	spawn_player(Vector3(0, 1, 1))

	# The key called Promise — sometimes already in the pilgrim's bosom.
	if SpiritualStateManager.has_promise_key:
		GameState.set_flag("found_promise_key", true)
		EventBus.toast("You feel the key called Promise near your heart; despair had made you forget it.")
	else:
		make_interactable(Vector3(-2.8, 0, 2), "Search the cell",
			func(_p):
				SpiritualStateManager.has_promise_key = true
				GameState.set_flag("found_promise_key", true)
				QuestManager.update_quest_progress("escape_doubting_castle")
				EventBus.toast("In your own breast pocket: Promise, waiting where despair told you not to look.")
			, null, Color(0.85, 0.8, 0.5), 0.8, 1.2, true)

	# The locked door.
	make_floating_label("Locked Door — Promise fits", Vector3(0, 4, -4), Color(0.8, 0.7, 0.6))
	make_interactable(Vector3(0, 0, -4.6), "Unlock the door with Promise",
		func(_p): _try_door(door), null, Color(0.3, 0.28, 0.24), 0.0, 1.6, false)

	# Giant Despair prowls the hall beyond the cell.
	var giant := SymbolicEnemy.new()
	giant.load_from_data("despair_wraith")
	giant.display_name = "Giant Despair"
	giant.influence = 9999.0
	add_child(giant)
	giant.global_position = Vector3(0, 1, -14)

	make_distant_light(Vector3(0, 5, -30), Color(0.7, 0.75, 0.9))

	# The cell's oppression drowns the screen edges as despair mounts.
	_vignette = DarkVignette.new()
	_vignette.edge_color = Color(0.03, 0.05, 0.12)
	add_child(_vignette)


func _process(delta: float) -> void:
	# Edge-darkening tracks despair, easing off once you escape into clean air.
	if is_instance_valid(_vignette):
		var d := 0.0 if GameState.has_flag("escaped_castle") else float(SpiritualStateManager.despair) / 100.0
		_vignette.set_intensity(d * 0.85)
	# The Giant's oppressive presence presses despair on you until you escape.
	if GameState.has_flag("escaped_castle"):
		return
	_aura += delta
	if _aura >= 4.0:
		_aura = 0.0
		SpiritualStateManager.modify_state("despair", 3)


func _try_door(door: Node) -> void:
	if not GameState.has_flag("found_promise_key"):
		EventBus.toast("The door will not give to force. Remember the key called Promise.")
		return
	if is_instance_valid(door):
		door.queue_free()
	GameState.set_flag("escaped_castle", true)
	QuestManager.update_quest_progress("escape_doubting_castle")
	EventBus.toast("The lock turns easily. What despair called final opens into clean air.")
	_advance_after_delay()
