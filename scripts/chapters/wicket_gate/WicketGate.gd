extends GlbChapter
class_name WicketGate
## Chapter 4. The narrow gate. Arrows of accusation chase you from behind, so
## press forward. Knock at the gate; Goodwill receives you and pulls you through.

var _arrows: ArrowEmitter = null
const TRUTH_SHIELD := preload("res://scripts/level/TruthShield.gd")
var _shield: Node = null
var _tower_built: bool = false
var _knock_access_built: bool = false
var _gate_door: Node3D = null
var _gate_door_closed_position: Vector3 = Vector3.ZERO
var _gate_opened: bool = false
var _entry_completed: bool = false


func _after_glb_built() -> void:
	_capture_gate_door()
	_install_wicket_gate_pressure()
	_install_knock_access()


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
	_install_knock_access()

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
	if EventBus.has_signal("game_flag_changed") and not EventBus.game_flag_changed.is_connected(_on_game_flag_changed):
		EventBus.game_flag_changed.connect(_on_game_flag_changed)
	if GameState.has_flag("passed_wicket_gate"):
		_open_gate_visual(false)
		_complete_gate_entry.call_deferred()
	elif GameState.has_flag("knocked_gate"):
		# Recover older saves created while node-level dialogue flags were ignored.
		# Reopen the decision immediately instead of leaving the player at a shut door.
		_start_knock_dialogue.call_deferred()


func _install_knock_access() -> void:
	if _knock_access_built:
		return
	_knock_access_built = true
	var gate_pos := Vector3(0, 1.2, -5.8) if _used_glb else Vector3(0, 1.2, -19.0)
	var interact_pos := Vector3(0, 0, -5.8) if _used_glb else Vector3(0, 0, -19.0)
	var trigger_size := Vector3(7.2, 3.4, 5.2) if _used_glb else Vector3(5.2, 3.4, 5.0)
	var interact_radius := 3.8 if _used_glb else 3.0
	var knock_cb := func(_body):
		_start_knock_dialogue()
	make_trigger(gate_pos, trigger_size, knock_cb, false)
	make_interactable(interact_pos, "叩门进入：向前走或点「互动」",
		func(_p): _start_knock_dialogue(),
		null, Color(0.85, 0.72, 0.42), 0.25, interact_radius)
	make_floating_label("继续向前会自动叩门；也可点「互动」",
		gate_pos + Vector3(0, 1.8, 0), Color(1.0, 0.92, 0.55))


func _start_knock_dialogue() -> void:
	if GameState.has_flag("passed_wicket_gate"):
		return
	if DialogueManager.is_active():
		return
	GameState.set_flag("knocked_gate", true)
	QuestManager.update_quest_progress("enter_gate")
	DialogueManager.start_dialogue("wicket_gate_knock")


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "wicket_gate_knock" and GameState.has_flag("passed_wicket_gate"):
		_complete_gate_entry()


func _on_game_flag_changed(flag_name: String, _old_value: Variant, new_value: Variant) -> void:
	if flag_name == "passed_wicket_gate" and bool(new_value):
		_open_gate_visual(true)


func _capture_gate_door() -> void:
	var found := find_child("PROP_GateDoor", true, false)
	if found is Node3D:
		_gate_door = found as Node3D
		_gate_door_closed_position = _gate_door.position


func _open_gate_visual(animate: bool = true) -> void:
	if _gate_opened:
		return
	_gate_opened = true
	if not is_instance_valid(_gate_door):
		return
	_set_gate_collision_disabled(_gate_door)
	var open_position := _gate_door_closed_position + Vector3(0, 4.8, 0)
	if animate:
		var tween := create_tween()
		tween.tween_property(_gate_door, "position", open_position, 0.72) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		_gate_door.position = open_position


func _set_gate_collision_disabled(root: Node) -> void:
	if root is CollisionShape3D:
		(root as CollisionShape3D).set_deferred("disabled", true)
	for child in root.get_children():
		_set_gate_collision_disabled(child)


func _complete_gate_entry() -> void:
	if _entry_completed:
		return
	_entry_completed = true
	_open_gate_visual(true)
	GameState.set_flag("knocked_gate", true)
	if _arrows != null:
		_arrows.active = false
	QuestManager.update_quest_progress("enter_gate")
	if is_instance_valid(player):
		# Just inside the gate, before the chapter exit. The player continues forward
		# into the Scripture Gate instead of being silently advanced past it.
		player.teleport(Vector3(0, 1, -10.4))
	make_light_burst(Vector3(0, 2.2, -8), Color(1.0, 0.88, 0.48), 48)
	EventBus.toast("窄门已经打开；善意把你拉进门内。继续向前进入经文之门。")


func is_gate_open() -> bool:
	return _gate_opened


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
