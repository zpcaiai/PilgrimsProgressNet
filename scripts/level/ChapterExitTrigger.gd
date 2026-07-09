extends Area3D
class_name ChapterExitTrigger
## Advances the pilgrimage when the player walks into it. Sets the current
## chapter's completion flag(s), optionally gated behind a precondition flag,
## then asks ChapterManager to move on (which applies completion effects and
## loads the next chapter from the active route). Built by ImportedSceneBinder
## from a TRIGGER_Exit_* box.

var set_flags: Dictionary = {}
var require_flag: String = ""
var require_message: String = "你还没有预备好离开。"
var target_chapter: String = ""
var quest_id: String = ""
var toast_line: String = ""
var _fired: bool = false
var _gate_open: bool = false


func setup(size: Vector3, p_set_flags: Dictionary = {}, p_require: String = "",
		p_message: String = "", p_target: String = "", p_quest: String = "",
		p_toast: String = "") -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	set_flags = p_set_flags
	require_flag = p_require
	if p_message != "":
		require_message = p_message
	target_chapter = p_target
	quest_id = p_quest
	toast_line = p_toast
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if _fired or _gate_open or not body.is_in_group("player"):
		return
	if require_flag != "" and not GameState.has_flag(require_flag):
		EventBus.toast(require_message)
		return
	if String(ChapterManager.current_chapter_id) == "hill_difficulty" and not SpiritualStateManager.has_scroll:
		EventBus.toast("你的书卷不在怀中。回到凉亭拾回凭据，再继续前往美宫。")
		return
	# Scripture Gate: the chapter's key verse must be answered before passing on.
	var cid := String(ChapterManager.current_chapter_id)
	if not GameState.has_flag("scripture_" + cid) and ScriptureGate.has_question(cid):
		_gate_open = true
		var on_pass := func() -> void:
			GameState.set_flag("scripture_" + cid, true)
			_gate_open = false
			_advance()
		var on_leave := func() -> void:
			_gate_open = false
		ScriptureGate.open(self, cid, on_pass, on_leave)
		return
	_advance()


func _advance() -> void:
	if _fired:
		return
	_fired = true
	var cid := String(ChapterManager.current_chapter_id)
	await _ensure_exit_reflection(cid)
	for k in set_flags.keys():
		GameState.set_flag(String(k), set_flags[k])
	if quest_id != "":
		QuestManager.update_quest_progress(quest_id)
	if toast_line != "":
		EventBus.toast(toast_line)
	await get_tree().create_timer(0.4).timeout
	if target_chapter != "":
		ChapterManager.complete_chapter(ChapterManager.current_chapter_id)
		ChapterManager.start_chapter(target_chapter)
	else:
		ChapterManager.go_to_next_chapter()


func _ensure_exit_reflection(chapter_id: String) -> void:
	if chapter_id == "" or GameState.has_flag("reflected_" + chapter_id):
		return
	if ScriptureMemory.get_chapter_card(chapter_id).is_empty():
		return
	var moment := ScriptureMemory.chapter_reflection_moment(chapter_id)
	if get_tree().get_nodes_in_group("learning_moment_panel").is_empty():
		ScriptureMemory.mark_reflected(chapter_id)
		return
	EventBus.learning_moment_requested.emit(moment)
	while is_instance_valid(self) and not GameState.has_flag("reflected_" + chapter_id):
		await get_tree().process_frame
