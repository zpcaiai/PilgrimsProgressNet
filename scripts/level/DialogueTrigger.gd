extends Area3D
class_name DialogueTrigger
## Starts a dialogue when the player enters. Built by ImportedSceneBinder from a
## TRIGGER_* box whose name maps to a dialogue id (e.g. TRIGGER_PliableLeaves ->
## "pliable_leaves"). Fires once by default.

var dialogue_id: String = ""
var once: bool = true
var require_flag: String = ""
var _fired: bool = false


func setup(size: Vector3, p_dialogue: String, p_once: bool = true,
		p_require: String = "") -> void:
	dialogue_id = p_dialogue
	once = p_once
	require_flag = p_require
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if once and _fired:
		return
	if require_flag != "" and not GameState.has_flag(require_flag):
		return
	if DialogueManager.is_active():
		return
	_fired = true
	DialogueManager.start_dialogue(dialogue_id)
