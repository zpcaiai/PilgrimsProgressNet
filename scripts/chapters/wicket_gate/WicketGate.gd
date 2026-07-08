extends GlbChapter
class_name WicketGate
## Chapter 4. The narrow gate. Arrows of accusation chase you from behind, so
## press forward. Knock at the gate; Goodwill receives you and pulls you through.

var _arrows: ArrowEmitter = null
const TRUTH_SHIELD := preload("res://scripts/level/TruthShield.gd")
var _shield: Node = null
var _tower_built: bool = false


func _after_glb_built() -> void:
	_install_wicket_gate_pressure()


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

	_install_wicket_gate_pressure()

func _install_wicket_gate_pressure() -> void:
	if not is_instance_valid(player):
		return
	if not is_instance_valid(_arrows):
		_build_beelzebub_tower()
		# Arrows from the old life, behind you.
		_arrows = ArrowEmitter.new()
		_arrows.position = player.global_position + Vector3(0, 1.2, 13)
		add_child(_arrows)
		_arrows.setup(player)
	if not is_instance_valid(_shield):
		_shield = TRUTH_SHIELD.new()
		player.add_child(_shield)
		make_floating_label("点「盾牌」举起真理盾牌；桌面键位 L", player.global_position + Vector3(0, 2.0, -4), Color(1.0, 0.9, 0.45))
	if EventBus.has_signal("dialogue_ended") and not EventBus.dialogue_ended.is_connected(_on_dialogue_ended):
		EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "wicket_gate_knock" and GameState.has_flag("passed_wicket_gate"):
		if _arrows != null:
			_arrows.active = false
		QuestManager.update_quest_progress("enter_gate")
		if is_instance_valid(player):
			player.teleport(Vector3(0, 1, -25))
		make_light_burst(Vector3(0, 1.4, -22), Color(1.0, 0.88, 0.48), 48)
		EventBus.toast("善意把你拉进门内；火箭停在门槛之外。")
		_advance_after_delay()


func _build_beelzebub_tower() -> void:
	if _tower_built:
		return
	_tower_built = true
	# Distant oppressive tower, not a boss body: accusation is heard through arrows.
	make_block(Vector3(3.2, 9.0, 3.2), Color(0.08, 0.06, 0.08), Vector3(0, 4.5, 25))
	make_block(Vector3(4.8, 1.0, 4.8), Color(0.16, 0.07, 0.05), Vector3(0, 9.4, 25))
	var eye_light := OmniLight3D.new()
	eye_light.position = Vector3(0, 8.9, 23.5)
	eye_light.light_color = Color(1.0, 0.22, 0.08)
	eye_light.light_energy = 4.5
	eye_light.omni_range = 15.0
	add_child(eye_light)
	make_floating_label("Beelzebub 的远塔", Vector3(0, 10.5, 24), Color(0.95, 0.42, 0.25))
