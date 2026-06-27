extends GlbChapter
class_name WicketGate
## Chapter 4. The narrow gate. Arrows of accusation chase you from behind, so
## press forward. Knock at the gate; Goodwill receives you and pulls you through.

var _arrows: ArrowEmitter = null


func _build_procedural() -> void:
	setup_environment(
		Color(0.12, 0.12, 0.2),
		Color(0.3, 0.25, 0.2),
		0.5
	)
	make_ground(Vector2(10, 60), Color(0.3, 0.3, 0.34))

	# Narrow walls hemming the approach.
	make_block(Vector3(1, 4, 60), Color(0.2, 0.2, 0.24), Vector3(-6, 2, -10))
	make_block(Vector3(1, 4, 60), Color(0.2, 0.2, 0.24), Vector3(6, 2, -10))

	# The narrow gate — a real stone gatehouse, warm welcome spilling from beyond.
	PropKit.gatehouse(self, Vector3(0, 0, -22), Color(0.42, 0.4, 0.42))
	var gate_light := OmniLight3D.new()
	gate_light.position = Vector3(0, 3, -24)
	gate_light.light_color = Color(1.0, 0.92, 0.7)
	gate_light.light_energy = 5.0
	gate_light.omni_range = 18.0
	add_child(gate_light)

	make_npc("Goodwill", Vector3(0, 0, -26), Color(0.9, 0.85, 0.65), "", "")

	# The knock interaction sits at the gate.
	make_interactable(Vector3(0, 0, -21), "叩窄门 (Knock)",
		func(_p): DialogueManager.start_dialogue("wicket_gate_knock"),
		null, Color(0.7, 0.6, 0.4), 0.0, 2.0)

	spawn_player(Vector3(0, 1, 14))

	# Arrows from the old life, behind you.
	_arrows = ArrowEmitter.new()
	_arrows.position = Vector3(0, 1.5, 20)
	add_child(_arrows)
	_arrows.setup(player)

	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "wicket_gate_knock" and GameState.has_flag("passed_wicket_gate"):
		if _arrows != null:
			_arrows.active = false
		QuestManager.update_quest_progress("enter_gate")
		EventBus.toast("善意把你拉进门内；控告停在门槛之外。")
		_advance_after_delay()
