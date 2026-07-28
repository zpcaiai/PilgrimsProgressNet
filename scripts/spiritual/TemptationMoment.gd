extends Node
class_name TemptationMoment
## Fires each chapter's TEMPTATION MOMENT once, at the point where the chapter's
## characteristic pressure has actually built up.
##
## This is the runtime half of the batch-4 fix described in
## tools/data_gen/build_temptation_dialogues.py. Two systems existed and had
## never met:
##
##   * `SpiritualStateManager.get_temptation_resistance()` / `can_resist_temptation()`
##     model ten named temptations against your current spiritual posture.
##     `DialogueManager` already honours `"conditions": {"temptation": {...}}`.
##   * `data/chapters/*.json` carries a hand-authored `design.primary_temptation`
##     per chapter — its type, the lie it whispers, and what would resist it.
##
## Nothing joined them, so the resistance model never affected a single line of
## dialogue. This node is the join. It waits until the moment is EARNED — the
## chapter's own negative pressure has risen, or the pilgrim has been walking
## long enough for the thought to arrive — and then speaks it.
##
## Deliberately conservative: once per chapter, never during another dialogue,
## never while the player is locked, and it always leaves a flag so the ending
## review and later chapters can read what you did.

## Which spiritual state indicates that this temptation's pressure is real.
const PRESSURE_STATE := {
	"return_to_city": "fear",
	"despair": "despair",
	"comfort_shortcut": "weariness",
	"vanity": "pride",
	"shame": "shame",
	"doubt": "doubt",
	"sleep": "weariness",
	"false_teaching": "deception",
	"self_reliance": "pride",
	"fear": "fear",
}

## Pressure level at which the thought arrives on its own.
const PRESSURE_TRIGGER := 42
## ... or, failing that, after this long in the chapter, having actually walked.
const TIME_TRIGGER := 55.0
const DISTANCE_TRIGGER := 22.0

var chapter_id: String = ""
var _elapsed: float = 0.0
var _distance: float = 0.0
var _prev_pos: Vector3 = Vector3.ZERO
var _have_prev := false
var _fired := false
var _dialogue_id := ""
var _ttype := ""


func _ready() -> void:
	if chapter_id == "":
		chapter_id = String(ChapterManager.current_chapter_id)
	var data := ChapterManager.get_current_chapter_data()
	var design: Dictionary = data.get("design", {})
	var pt: Dictionary = design.get("primary_temptation", data.get("primary_temptation", {}))
	_ttype = String(pt.get("type", ""))
	_dialogue_id = "temptation_%s" % chapter_id
	# Nothing authored for this chapter, or already met this journey.
	if _ttype == "" or GameState.has_flag("temptation_%s_seen" % chapter_id):
		_fired = true
		set_process(false)
		return
	if not DialogueManager.has_dialogue(_dialogue_id):
		_fired = true
		set_process(false)


func _process(delta: float) -> void:
	if _fired:
		return
	_elapsed += delta
	var p := _player()
	if p != null:
		if _have_prev:
			var d: Vector3 = p.global_position - _prev_pos
			_distance += Vector2(d.x, d.z).length()
		_prev_pos = p.global_position
		_have_prev = true

	if not _should_fire():
		return
	# Never interrupt: a temptation that talks over a conversation, a cutscene
	# or a boss fight reads as a bug, not as a thought.
	if DialogueManager.is_active():
		return
	if p == null or (p is PlayerController and (p as PlayerController).control_locked):
		return
	_fire()


func _should_fire() -> bool:
	var state := String(PRESSURE_STATE.get(_ttype, "despair"))
	if SpiritualStateManager.get_state(state) >= PRESSURE_TRIGGER:
		return true
	return _elapsed >= TIME_TRIGGER and _distance >= DISTANCE_TRIGGER


func _fire() -> void:
	_fired = true
	set_process(false)
	GameState.set_flag("temptation_%s_seen" % chapter_id, true)
	# A beat of stillness before the thought lands, so it does not collide with
	# whatever the player was doing in the instant it triggered.
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or DialogueManager.is_active():
		return
	DialogueManager.start_dialogue(_dialogue_id)


func _player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Node3D


## Did the pilgrim stand in this chapter's characteristic temptation?
## "resisted" / "struggled" / "yielded" / "" (never met it).
static func outcome(cid: String) -> String:
	if GameState.has_flag("resisted_%s" % cid):
		return "resisted"
	if GameState.has_flag("struggled_%s" % cid):
		return "struggled"
	if GameState.has_flag("yielded_%s" % cid):
		return "yielded"
	return ""


## How many chapters' temptations were met head-on — read by the ending review.
static func tally() -> Dictionary:
	var out := {"resisted": 0, "struggled": 0, "yielded": 0, "unmet": 0}
	for cid in ChapterManager.route:
		var o := outcome(String(cid))
		if o == "":
			out["unmet"] = int(out["unmet"]) + 1
		else:
			out[o] = int(out[o]) + 1
	return out
