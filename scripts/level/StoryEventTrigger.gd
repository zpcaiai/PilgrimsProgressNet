extends Area3D
class_name StoryEventTrigger
## Applies a one-shot "spiritual event" when entered: effects, flags, special
## grants and an inner-voice toast. Used for symbolic beats that are not full
## dialogues -- e.g. reading the warning book (receive_burden) or an Interpreter
## room. Configured by ImportedSceneBinder.

var effects: Dictionary = {}
var flags: Dictionary = {}
var special: Dictionary = {}
var toast_line: String = ""
var once: bool = true
var _fired: bool = false


func setup(size: Vector3, p_effects: Dictionary = {}, p_flags: Dictionary = {},
		p_special: Dictionary = {}, p_toast: String = "", p_once: bool = true) -> void:
	effects = p_effects
	flags = p_flags
	special = p_special
	toast_line = p_toast
	once = p_once
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)


func fire() -> void:
	if once and _fired:
		return
	_fired = true
	if not effects.is_empty():
		SpiritualStateManager.apply_effects(effects)
	for k in flags.keys():
		GameState.set_flag(String(k), flags[k])
	if not special.is_empty():
		SpiritualStateManager._apply_special(special)
	if toast_line != "":
		EventBus.toast(toast_line)


func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		fire()
