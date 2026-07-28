extends Area3D
class_name Interactable
## Base interactable. Built procedurally by chapter scripts.
## Lives on collision layer 2 so the player's interactor (mask 2) detects it.

var prompt: String = "互动"
var interact_callback: Callable = Callable()
var one_shot: bool = false
var consumed: bool = false
var _auto_dialogue_id: String = ""
var _auto_facing_root: Node3D = null
var _auto_proximity: Area3D = null
var _auto_player_inside: bool = false
var _auto_pending: bool = false
var _last_auto_started_ms: int = -10000

const AUTO_DIALOGUE_DELAY := 0.16
const AUTO_DIALOGUE_COOLDOWN_MS := 900


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func can_interact() -> bool:
	return not (one_shot and consumed)


func interact(player: Node) -> void:
	if not can_interact():
		return
	if one_shot:
		consumed = true
	AudioManager.play_sfx("interact")
	if interact_callback.is_valid():
		interact_callback.call(player)


## Gives a person a separate approach radius without changing the ordinary
## interaction area used by touch/keyboard controls. One entry starts one
## conversation; the player must leave and approach again before it can repeat.
func enable_auto_dialogue(p_dialogue_id: String, facing_root: Node3D = null,
		radius: float = 2.6) -> void:
	if p_dialogue_id == "" or is_instance_valid(_auto_proximity):
		return
	_auto_dialogue_id = p_dialogue_id
	_auto_facing_root = facing_root if is_instance_valid(facing_root) else self
	add_to_group("auto_dialogue_person")
	_auto_proximity = Area3D.new()
	_auto_proximity.name = "AutoDialogueProximity"
	_auto_proximity.collision_layer = 0
	_auto_proximity.collision_mask = 1
	_auto_proximity.monitoring = true
	_auto_proximity.monitorable = false
	_auto_proximity.add_to_group("npc_auto_dialogue")
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = maxf(radius, 1.2)
	shape_node.shape = shape
	shape_node.position = Vector3(0, 1.0, 0)
	_auto_proximity.add_child(shape_node)
	add_child(_auto_proximity)
	_auto_proximity.body_entered.connect(_on_auto_dialogue_entered)
	_auto_proximity.body_exited.connect(_on_auto_dialogue_exited)


func face_toward_player(player: Node) -> void:
	if not is_instance_valid(player) or not (player is Node3D):
		return
	if player.has_method("glance_toward"):
		player.call("glance_toward", global_position)
	var root := _auto_facing_root if is_instance_valid(_auto_facing_root) else self
	var direction := (player as Node3D).global_position - root.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		var target_yaw := atan2(direction.x, direction.z)
		var tween := root.create_tween()
		tween.tween_property(root, "rotation:y", target_yaw, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var anim := HumanoidAnimator.find_in(root)
	if anim != null:
		anim.nudge(0.07)
		# Hold eye contact for the length of the conversation. The body turn
		# above is a 0.18 s snap; head tracking is what makes an NPC feel like
		# it is listening to you rather than merely pointed at you.
		anim.look_at_node(player as Node3D)
		_hold_gaze(anim)


## Keep the NPC's head on the player until the conversation ends, then release
## it back to idle drift.
func _hold_gaze(anim: HumanoidAnimator) -> void:
	if not is_instance_valid(anim):
		return
	await get_tree().create_timer(0.5).timeout
	while is_instance_valid(anim) and DialogueManager.is_active():
		await get_tree().create_timer(0.4).timeout
	# Linger a beat after the dialogue closes so the release never snaps.
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(anim):
		anim.clear_look_target()


func has_auto_dialogue() -> bool:
	return _auto_dialogue_id != "" and is_instance_valid(_auto_proximity)


func get_auto_dialogue_id() -> String:
	return _auto_dialogue_id


func _on_auto_dialogue_entered(body: Node) -> void:
	if not body.is_in_group("player") or _auto_player_inside or _auto_pending:
		return
	_auto_player_inside = true
	if DialogueManager.is_active():
		return
	if Time.get_ticks_msec() - _last_auto_started_ms < AUTO_DIALOGUE_COOLDOWN_MS:
		return
	_auto_pending = true
	face_toward_player(body)
	_start_auto_dialogue_after_turn(body)


func _start_auto_dialogue_after_turn(player: Node) -> void:
	await get_tree().create_timer(AUTO_DIALOGUE_DELAY).timeout
	if not _auto_player_inside or not is_instance_valid(player) or DialogueManager.is_active():
		_auto_pending = false
		return
	_last_auto_started_ms = Time.get_ticks_msec()
	_auto_pending = false
	DialogueManager.start_dialogue(_auto_dialogue_id)


func _on_auto_dialogue_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_auto_player_inside = false
		_auto_pending = false
