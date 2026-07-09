extends Node
## InputManager
## Godot-native unified input layer. It keeps a single gameplay context and
## exposes the same actions to keyboard, gamepad and mobile controls.
## Autoloaded as "InputManager".

const CTX_GAMEPLAY := "gameplay"
const CTX_DIALOGUE := "dialogue"
const CTX_MENU := "menu"
const CTX_CUTSCENE := "cutscene"
const CTX_COMBAT := "combat"

const ACTION_MOVE_UP := "move_forward"
const ACTION_MOVE_DOWN := "move_back"
const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_INTERACT := "interact"
const ACTION_CONFIRM := "ui_accept"
const ACTION_CANCEL := "ui_cancel"
const ACTION_PRAY := "pray"
const ACTION_REPENT := "repent"
const ACTION_MENU := "open_menu"
const ACTION_JOURNAL := "open_journal"
const ACTION_RECENTER := "recenter_player"
const ACTION_DASH := "dash"
const ACTION_ATTACK := "combat_attack"
const ACTION_GUARD := "combat_guard"
const ACTION_PROMISE := "combat_promise"
const ACTION_DODGE := "combat_dodge"

var context: String = CTX_GAMEPLAY
var enabled: bool = true
var _movement_locked: bool = false
var _virtual_move: Vector2 = Vector2.ZERO
var _last_pressed: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions()
	if EventBus.has_signal("dialogue_started"):
		EventBus.dialogue_started.connect(func(_id): set_context(CTX_DIALOGUE))
	if EventBus.has_signal("dialogue_ended"):
		EventBus.dialogue_ended.connect(func(_id): set_context(CTX_GAMEPLAY))
	if EventBus.has_signal("player_control_locked"):
		EventBus.player_control_locked.connect(func(v): _movement_locked = bool(v))


func _process(_delta: float) -> void:
	if not enabled:
		return
	if get_tree().paused and context != CTX_MENU:
		context = CTX_MENU
	elif not get_tree().paused and context == CTX_MENU:
		context = CTX_DIALOGUE if DialogueManager and DialogueManager.is_active() else _gameplay_or_combat_context()
	elif not get_tree().paused and context not in [CTX_DIALOGUE, CTX_MENU, CTX_CUTSCENE]:
		var target := _gameplay_or_combat_context()
		if target != context:
			set_context(target)
	_handle_global_actions()


func _ensure_actions() -> void:
	var defs := {
		ACTION_MOVE_UP: [KEY_W, KEY_UP],
		ACTION_MOVE_DOWN: [KEY_S, KEY_DOWN],
		ACTION_MOVE_LEFT: [KEY_A, KEY_LEFT],
		ACTION_MOVE_RIGHT: [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		ACTION_INTERACT: [KEY_E],
		ACTION_CONFIRM: [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
		ACTION_CANCEL: [KEY_ESCAPE, KEY_BACKSPACE],
		ACTION_PRAY: [KEY_Q, KEY_P],
		ACTION_REPENT: [KEY_R],
		ACTION_MENU: [KEY_ESCAPE],
		ACTION_JOURNAL: [KEY_J, KEY_TAB],
		ACTION_RECENTER: [KEY_H],
		ACTION_DASH: [KEY_SHIFT],
		ACTION_ATTACK: [KEY_J],
		ACTION_GUARD: [KEY_L],
		ACTION_PROMISE: [KEY_U],
		ACTION_DODGE: [KEY_K],
	}
	for action in defs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in defs[action]:
			if not _action_has_key(action, keycode):
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action, ev)


func _action_has_key(action: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.physical_keycode == keycode or ev.keycode == keycode):
			return true
	return false


func set_context(next_context: String) -> void:
	if context == next_context:
		return
	var old := context
	context = next_context
	EventBus.input_context_changed.emit(old, context)


func lock_all_input(reason: String = "") -> void:
	enabled = false
	EventBus.input_locked.emit(reason)


func unlock_all_input(reason: String = "") -> void:
	enabled = true
	EventBus.input_unlocked.emit(reason)


func set_virtual_movement(vec: Vector2) -> void:
	_virtual_move = vec.limit_length(1.0)


func clear_virtual_movement() -> void:
	_virtual_move = Vector2.ZERO


func get_movement_vector() -> Vector2:
	if not can_move():
		return Vector2.ZERO
	var keyboard := Vector2(
		Input.get_action_strength(ACTION_MOVE_RIGHT) - Input.get_action_strength(ACTION_MOVE_LEFT),
		Input.get_action_strength(ACTION_MOVE_DOWN) - Input.get_action_strength(ACTION_MOVE_UP)
	)
	if keyboard.length() > 1.0:
		keyboard = keyboard.normalized()
	return _virtual_move if _virtual_move.length() > keyboard.length() else keyboard


func get_movement_vector_3d(camera_yaw_degrees: float = 0.0) -> Vector3:
	var v := get_movement_vector()
	var out := Vector3(v.x, 0, v.y)
	if out.length() > 1.0:
		out = out.normalized()
	if out.length() > 0.0:
		out = out.rotated(Vector3.UP, deg_to_rad(camera_yaw_degrees))
	return out


func can_move() -> bool:
	return enabled and not _movement_locked and context in [CTX_GAMEPLAY, CTX_COMBAT]


func can_interact() -> bool:
	return enabled and context in [CTX_GAMEPLAY, CTX_COMBAT]


func _gameplay_or_combat_context() -> String:
	return CTX_COMBAT if not get_tree().get_nodes_in_group("enemy").is_empty() else CTX_GAMEPLAY


func is_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func was_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func debug_snapshot() -> Dictionary:
	var pressed: Array = []
	for a in [ACTION_MOVE_UP, ACTION_MOVE_DOWN, ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT,
			ACTION_INTERACT, ACTION_PRAY, ACTION_REPENT, ACTION_ATTACK, ACTION_DODGE,
			ACTION_GUARD, ACTION_PROMISE, ACTION_MENU, ACTION_JOURNAL, ACTION_RECENTER]:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			pressed.append(a)
	return {
		"context": context,
		"enabled": enabled,
		"movement_locked": _movement_locked,
		"movement": get_movement_vector(),
		"pressed": pressed,
		"virtual": _virtual_move,
	}


func _handle_global_actions() -> void:
	if context == CTX_DIALOGUE or context == CTX_MENU:
		return
	if Input.is_action_just_pressed(ACTION_PRAY):
		EventBus.input_pray.emit()
		if _should_handle_noncombat_spiritual_action():
			SpiritualStateManager.pray("input")
	if Input.is_action_just_pressed(ACTION_REPENT):
		EventBus.input_repent.emit()
		if _should_handle_noncombat_spiritual_action():
			SpiritualStateManager.repent("input")
	if context == CTX_GAMEPLAY and Input.is_action_just_pressed(ACTION_JOURNAL):
		EventBus.input_open_journal.emit()
	if context == CTX_GAMEPLAY and Input.is_action_just_pressed(ACTION_RECENTER):
		EventBus.input_recenter.emit()


func _should_handle_noncombat_spiritual_action() -> bool:
	return get_tree().get_nodes_in_group("enemy").is_empty()
