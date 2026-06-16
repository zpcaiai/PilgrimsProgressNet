extends CanvasLayer
## TouchControls (instanced by Main, like NetUI)
## On-screen virtual keypad so the game is playable on phones/tablets with no
## physical keyboard. Every button injects the matching InputEventKey (keycode +
## physical_keycode), so it drives the exact same handlers the keyboard does:
##   WASD = move_* actions · Space = jump · E = interact / advance dialogue
##   1-4  = dialogue choices · C = heart · Tab = map · Esc = pause
## Self-building, responsive (lays out from the viewport size), full multitouch
## (hold a direction + tap an action). Only active when a touchscreen is present.
## Landscape-only: shows a "rotate" hint while the device is held portrait.

const MARGIN := 0.05      # all sizes are fractions of min(viewport w, h)
const DPAD_R := 0.078
const ACT_R := 0.10
const UTIL_R := 0.058
const CHOICE_R := 0.05

# id -> keycode. WASD use physical keys (actions are bound to physical W/A/S/D);
# the rest are read as event.keycode by the UI handlers.
const KEYS := {
	"W": KEY_W, "A": KEY_A, "S": KEY_S, "D": KEY_D,
	"SPACE": KEY_SPACE, "E": KEY_E,
	"C": KEY_C, "TAB": KEY_TAB, "ESC": KEY_ESCAPE,
	"1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4,
}
const LABELS := {
	"W": "W", "A": "A", "S": "S", "D": "D",
	"SPACE": "跳", "E": "用",
	"C": "心", "TAB": "图", "ESC": "退",
	"1": "1", "2": "2", "3": "3", "4": "4",
}

var _enabled := false
var _in_game := false
var _locked := false
var _dialogue := false
var _choices := 0
var _was_paused := false

# finger index -> button id currently held by that finger
var _fingers := {}
var _pad: Control


class _Pad extends Control:
	var ctl
	func _draw() -> void:
		if ctl:
			ctl._draw_pad(self)
	func _input(event) -> void:
		if ctl:
			ctl._on_input(event)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = DisplayServer.is_touchscreen_available()
	_pad = _Pad.new()
	_pad.ctl = self
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pad)
	_connect(EventBus, "game_started", _on_game_started)
	_connect(EventBus, "player_control_locked", _on_lock)
	_connect(EventBus, "dialogue_started", _on_dialogue_started)
	_connect(EventBus, "dialogue_node_changed", _on_dialogue_node)
	_connect(EventBus, "dialogue_ended", _on_dialogue_ended)
	_refresh()


func _connect(obj: Object, sig: String, cb: Callable) -> void:
	if obj and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


# --- Public: Main toggles this when entering / leaving gameplay ---
func set_gameplay(on: bool) -> void:
	_in_game = on
	if not on:
		_release_all()
	_refresh()


# --- EventBus reactions ---
func _on_game_started() -> void:
	_in_game = true
	_refresh()

func _on_lock(locked: bool) -> void:
	_locked = locked
	if locked:
		_release_dir()
	_refresh()

func _on_dialogue_started(_id := "") -> void:
	_dialogue = true
	_refresh()

func _on_dialogue_node(_node := {}) -> void:
	_choices = 0
	if DialogueManager and DialogueManager.has_method("get_available_choices"):
		_choices = (DialogueManager.get_available_choices() as Array).size()
	_refresh()

func _on_dialogue_ended(_id := "") -> void:
	_dialogue = false
	_choices = 0
	_refresh()


func _process(_dt: float) -> void:
	var p := get_tree().paused
	if p != _was_paused:
		_was_paused = p
		if p:
			_release_dir()
		_refresh()


func _refresh() -> void:
	visible = _enabled and _in_game
	if _pad:
		_pad.queue_redraw()


# ---------------------------------------------------------------- visibility
func _portrait() -> bool:
	var s := _vsize()
	return s.y > s.x

func _btn_ids() -> Array:
	# Which buttons are currently live, given game state.
	if not _in_game or _portrait():
		return []
	var paused := get_tree().paused
	var out: Array = []
	if not paused and not _locked:
		out.append_array(["W", "A", "S", "D", "SPACE"])
	if not paused:
		out.append("E")               # E also advances dialogue
		out.append_array(["C", "TAB"])
		if _dialogue and _choices > 0:
			for i in range(min(_choices, 4)):
				out.append(str(i + 1))
	out.append("ESC")                 # always available in-game (incl. to resume)
	return out


# ---------------------------------------------------------------- geometry
func _vsize() -> Vector2:
	if _pad:
		return _pad.size
	return get_viewport().get_visible_rect().size

func _layout() -> Dictionary:
	# Returns id -> {center:Vector2, radius:float}
	var s := _vsize()
	var u: float = min(s.x, s.y)
	var m := u * MARGIN
	var dr := u * DPAD_R
	var ar := u * ACT_R
	var ur := u * UTIL_R
	var cr := u * CHOICE_R
	var out := {}
	# WASD d-pad, bottom-left (plus layout)
	var dc := Vector2(m + dr * 2.3, s.y - m - dr * 2.3)
	var g := dr * 2.15
	out["W"] = {"center": dc + Vector2(0, -g), "radius": dr}
	out["A"] = {"center": dc + Vector2(-g, 0), "radius": dr}
	out["S"] = {"center": dc + Vector2(0, g), "radius": dr}
	out["D"] = {"center": dc + Vector2(g, 0), "radius": dr}
	# Action buttons, bottom-right
	out["SPACE"] = {"center": Vector2(s.x - m - ar, s.y - m - ar), "radius": ar}
	out["E"] = {"center": Vector2(s.x - m - ar * 2.6, s.y - m - ar * 0.45), "radius": ar * 0.86}
	# Utility, top-right row
	var ey := m + ur
	out["ESC"] = {"center": Vector2(s.x - m - ur, ey), "radius": ur}
	out["TAB"] = {"center": Vector2(s.x - m - ur - ur * 2.3, ey), "radius": ur}
	out["C"] = {"center": Vector2(s.x - m - ur - ur * 4.6, ey), "radius": ur}
	# Dialogue choices 1-4, bottom-center row
	var n: int = max(_choices, 1)
	var start := s.x * 0.5 - (n - 1) * cr * 1.2
	for i in range(4):
		out[str(i + 1)] = {"center": Vector2(start + i * cr * 2.4, s.y - m - cr), "radius": cr}
	return out


func _hit(pos: Vector2) -> String:
	var lay := _layout()
	for id in _btn_ids():
		var b: Dictionary = lay.get(id, {})
		if b.is_empty():
			continue
		if pos.distance_to(b["center"]) <= b["radius"] * 1.12:
			return id
	return ""


# ---------------------------------------------------------------- input
func _on_input(event) -> void:
	if not _enabled and (event is InputEventScreenTouch):
		# Touch detected even though the API said no touchscreen -> enable.
		_enabled = true
		_refresh()
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var id := _hit(t.position)
			if id != "":
				_fingers[t.index] = id
				_send(KEYS[id], true)
				_pad.queue_redraw()
		else:
			_release_finger(t.index)
	elif event is InputEventScreenDrag:
		# Let a finger slide between d-pad directions (e.g. W -> WD diagonal feel).
		var d := event as InputEventScreenDrag
		if _fingers.has(d.index):
			var held: String = _fingers[d.index]
			if held in ["W", "A", "S", "D"]:
				var now := _hit(d.position)
				if now in ["W", "A", "S", "D"] and now != held:
					_send(KEYS[held], false)
					_fingers[d.index] = now
					_send(KEYS[now], true)
					_pad.queue_redraw()


func _release_finger(index: int) -> void:
	if _fingers.has(index):
		var id: String = _fingers[index]
		_send(KEYS.get(id, 0), false)
		_fingers.erase(index)
		_pad.queue_redraw()

func _release_dir() -> void:
	for index in _fingers.keys().duplicate():
		if _fingers[index] in ["W", "A", "S", "D", "SPACE"]:
			_send(KEYS[_fingers[index]], false)
			_fingers.erase(index)

func _release_all() -> void:
	for index in _fingers.keys().duplicate():
		_send(KEYS.get(_fingers[index], 0), false)
	_fingers.clear()


func _send(keycode: int, pressed: bool) -> void:
	if keycode == 0:
		return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.echo = false
	Input.parse_input_event(ev)


# ---------------------------------------------------------------- drawing
func _draw_pad(pad: Control) -> void:
	if not _enabled:
		return
	if _in_game and _portrait():
		_draw_rotate_hint(pad)
		return
	var lay := _layout()
	var held := _fingers.values()
	for id in _btn_ids():
		var b: Dictionary = lay.get(id, {})
		if b.is_empty():
			continue
		_draw_button(pad, b["center"], b["radius"], LABELS.get(id, id), held.has(id))


func _draw_button(pad: Control, c: Vector2, r: float, label: String, on: bool) -> void:
	var fill := Color(0.12, 0.13, 0.18, 0.42 if not on else 0.72)
	var ring := Color(0.85, 0.88, 0.95, 0.55 if not on else 0.95)
	pad.draw_circle(c, r, fill)
	pad.draw_arc(c, r, 0.0, TAU, 40, ring, max(2.0, r * 0.06), true)
	var f := ThemeDB.fallback_font
	if get_tree().root.theme and get_tree().root.theme.default_font:
		f = get_tree().root.theme.default_font
	var fs := int(r * 0.95)
	var ts := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	pad.draw_string(f, c + Vector2(-ts.x * 0.5, ts.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.95, 0.9, 0.95 if on else 0.8))


func _draw_rotate_hint(pad: Control) -> void:
	var s := _vsize()
	pad.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.03, 0.05, 0.9), true)
	var f := ThemeDB.fallback_font
	if get_tree().root.theme and get_tree().root.theme.default_font:
		f = get_tree().root.theme.default_font
	var fs: int = int(min(s.x, s.y) * 0.06)
	var msg := "↻  请将手机横置游玩"
	var ts := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	pad.draw_string(f, Vector2(s.x * 0.5 - ts.x * 0.5, s.y * 0.5), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.93, 0.85))
