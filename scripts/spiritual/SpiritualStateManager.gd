extends Node
## SpiritualStateManager
## The heart of the game. Models inner formation as tensions rather than a
## single good/evil meter. All numeric states are 0-100.
## Autoloaded as "SpiritualStateManager".

const NUMERIC_STATES := [
	"faith", "hope", "humility", "discernment", "perseverance", "watchfulness",
	"despair", "shame", "fear", "pride", "deception", "weariness",
]

const POSITIVE_STATES := ["faith", "hope", "humility", "discernment", "perseverance", "watchfulness"]
const NEGATIVE_STATES := ["despair", "shame", "fear", "pride", "deception", "weariness"]

const BOOL_STATES := ["has_burden", "has_scroll", "has_seal", "has_promise_key", "has_new_garment"]

# --- Positive states ---
var faith: int = 5
var hope: int = 5
var humility: int = 10
var discernment: int = 5
var perseverance: int = 10
var watchfulness: int = 5

# --- Negative states ---
var despair: int = 35
var shame: int = 25
var fear: int = 20
var pride: int = 10
var deception: int = 10
var weariness: int = 5

# --- Story booleans ---
var has_burden: bool = true
var has_scroll: bool = false
var has_seal: bool = false
var has_promise_key: bool = false
var has_new_garment: bool = false

var _collapsed: bool = false


func reset_for_new_game() -> void:
	faith = 5
	hope = 5
	humility = 10
	discernment = 5
	perseverance = 10
	watchfulness = 5
	despair = 35
	shame = 25
	fear = 20
	pride = 10
	deception = 10
	weariness = 5
	has_burden = true
	has_scroll = false
	has_seal = false
	has_promise_key = false
	has_new_garment = false
	_collapsed = false


# --- Generic getters / setters ---
func get_state(state_name: String) -> int:
	if NUMERIC_STATES.has(state_name):
		return int(get(state_name))
	return 0


func clamp_state(value: int) -> int:
	return clampi(value, 0, 100)


func set_state(state_name: String, value: int) -> void:
	if not NUMERIC_STATES.has(state_name):
		return
	var old_value: int = int(get(state_name))
	var new_value: int = clamp_state(value)
	set(state_name, new_value)
	if new_value != old_value:
		EventBus.spiritual_state_changed.emit(state_name, old_value, new_value)
	_check_collapse()


func modify_state(state_name: String, delta: int) -> void:
	if not NUMERIC_STATES.has(state_name):
		return
	# Children's Journey: negative states (despair, fear, shame...) build at half
	# rate, so the road is far more forgiving. Positive gains are untouched.
	if delta > 0 and NEGATIVE_STATES.has(state_name) and GameState.is_child_mode():
		delta = int(ceil(delta * 0.5))
	set_state(state_name, int(get(state_name)) + delta)


# --- Effects dictionary ---
## Accepts a dict like:
## { "faith": 5, "despair": -10, "flags": {...}, "items": {...}, "special": {...} }
func apply_effects(effects: Dictionary) -> void:
	if effects.is_empty():
		return
	for key in effects.keys():
		match key:
			"flags":
				_apply_flags(effects[key])
			"items":
				_apply_items(effects[key])
			"special":
				_apply_special(effects[key])
			_:
				if NUMERIC_STATES.has(key):
					modify_state(key, int(effects[key]))


func _apply_flags(flags: Dictionary) -> void:
	for k in flags.keys():
		GameState.set_flag(String(k), flags[k])


func _apply_items(items: Dictionary) -> void:
	for k in items.keys():
		GameState.add_inventory_item(String(k), int(items[k]))


func _apply_special(special: Dictionary) -> void:
	if bool(special.get("remove_burden", false)):
		remove_burden()
	if bool(special.get("grant_scroll", false)):
		has_scroll = true
	if bool(special.get("grant_seal", false)):
		has_seal = true
	if bool(special.get("grant_new_garment", false)):
		has_new_garment = true
	if bool(special.get("grant_promise_key", false)):
		has_promise_key = true
	if bool(special.get("cross_grace", false)):
		apply_cross_grace()


# --- Burden & Cross ---
func remove_burden() -> void:
	if not has_burden:
		return
	has_burden = false
	EventBus.burden_removed.emit()


func apply_cross_grace() -> void:
	# Grace is not earned by stats. The burden falls regardless.
	has_burden = false
	has_scroll = true
	has_seal = true
	has_new_garment = true
	set_state("despair", 0)
	set_state("shame", 0)
	modify_state("fear", -60)
	modify_state("faith", 30)
	modify_state("hope", 30)
	modify_state("humility", 10)
	_collapsed = false
	EventBus.burden_removed.emit()
	EventBus.cross_grace_applied.emit()


# --- Derived values ---
func get_movement_multiplier() -> float:
	var penalty: float = 0.0
	if has_burden:
		penalty += 0.15
	penalty += despair * 0.0025
	penalty += fear * 0.0015
	penalty += weariness * 0.002
	penalty -= hope * 0.001
	penalty -= perseverance * 0.001
	# Vanity bought at the fair clings and weighs on the road (~3% each).
	penalty += GameState.get_item_count("vanity_token") * 0.03
	penalty = clampf(penalty, 0.0, 0.5)
	# Children's Journey: the burden and despair slow you only half as much.
	if GameState.is_child_mode():
		penalty *= 0.5
	return 1.0 - penalty


func get_movement_penalty() -> float:
	return 1.0 - get_movement_multiplier()


func get_visual_darkness() -> float:
	var darkness: float = despair * 0.006
	darkness += shame * 0.002
	darkness += fear * 0.002
	darkness -= hope * 0.002
	darkness -= faith * 0.001
	return clampf(darkness, 0.0, 0.85)


func get_inner_voice_tone() -> String:
	if despair > 80:
		return "hopeless"
	elif shame > 70:
		return "accusing"
	elif fear > 70:
		return "fearful"
	elif pride > 70:
		return "self_reliant"
	elif hope > 60 and faith > 60:
		return "steady"
	return "neutral"


func get_compass_stability() -> float:
	# 1.0 = steady, 0.0 = wildly flickering
	var instability: float = despair * 0.008 + fear * 0.004 - hope * 0.004
	return clampf(1.0 - instability, 0.0, 1.0)


func get_repentance_availability() -> bool:
	return humility >= 5


func get_help_receptivity() -> float:
	var r: float = humility * 0.01 - pride * 0.006
	return clampf(r, 0.0, 1.0)


# --- Temptation resistance ---
## Returns a score; the caller compares it to a difficulty threshold.
func get_temptation_resistance(temptation_type: String) -> int:
	match temptation_type:
		"return_to_city":
			return faith + perseverance + hope - fear - despair
		"despair":
			return hope + faith + humility - despair - shame
		"comfort_shortcut":
			return discernment + perseverance - weariness - deception
		"vanity":
			return humility + discernment - pride - deception
		"shame":
			return faith + hope + humility - shame
		"doubt":
			return faith + discernment + hope - fear - deception
		"sleep":
			return watchfulness + perseverance + hope - weariness
		"false_teaching":
			return discernment + watchfulness - deception
		"self_reliance":
			return humility - pride
		"fear":
			return faith + hope - fear
		_:
			return faith + hope - despair


func can_resist_temptation(temptation_type: String, difficulty: int) -> bool:
	return get_temptation_resistance(temptation_type) >= difficulty


# --- Collapse ---
func _check_collapse() -> void:
	if despair >= 100 and not _collapsed:
		_collapsed = true
		EventBus.spiritual_collapse.emit()


func is_collapsed() -> bool:
	return _collapsed


func clear_collapse() -> void:
	_collapsed = false


# --- Serialization ---
func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for s in NUMERIC_STATES:
		d[s] = int(get(s))
	for b in BOOL_STATES:
		d[b] = bool(get(b))
	return d


func from_dict(data: Dictionary) -> void:
	for s in NUMERIC_STATES:
		if data.has(s):
			set(s, clamp_state(int(data[s])))
	for b in BOOL_STATES:
		if data.has(b):
			set(b, bool(data[b]))
	_collapsed = false
