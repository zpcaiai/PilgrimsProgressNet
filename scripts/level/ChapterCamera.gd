extends Node
class_name ChapterCamera
## Uses the CAM_* markers that were already in every chapter's GLB — and that
## nothing read.
##
## tools/scene_gen/scene_defs.py authors 36 named camera markers across the 16
## chapters (CAM_SummitReveal, CAM_ValleyDescent, CAM_ThroneApproach, ...), and
## ImportedSceneBinder dutifully puts each one in the "cinematic_camera" group.
## Until now nothing in the project ever queried that group, so every chapter
## opened on the same over-the-shoulder gameplay view, whatever the author had
## framed. That is a large part of why the 16 chapters feel like one long
## corridor rather than a journey with places in it.
##
## This node does two things:
##
##   1. ESTABLISHING SHOT. On chapter start, it holds the chapter's overview
##      marker for a few seconds while the chapter title card and opening
##      narration play (the player is already narration-locked at that point,
##      so it costs no agency), then hands the camera back with an eased blend.
##
##   2. NAMED SHOTS ON DEMAND. Chapter scripts and the scene binder can call
##      ChapterCamera.shot("SummitReveal", 3.0) at a story beat — the telescope
##      on the Delectable Mountains, the gate opening at the Celestial City —
##      without any of them needing to know where the camera lives.
##
## Any input skips the shot. It never blocks progression, and it is completely
## inert if the chapter has no markers (the procedural fallback path).

## Preferred establishing markers, in priority order. The first suffix that
## matches a marker in this chapter wins.
const OVERVIEW_HINTS := ["Overview", "Wide", "Reveal", "Entrance", "Exterior", "Approach", "Entry"]

@export var intro_duration: float = 4.6
@export var enabled: bool = true

var _played: bool = false
var _armed: bool = false
var _delay: float = 0.55


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	if _played or not enabled:
		set_process(false)
		return
	if not QualityTier.allow_cinematic_intro():
		_played = true
		return
	# Let the binder finish and the fade-in start before framing anything.
	_delay -= delta
	if _delay > 0.0:
		return
	_played = true
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if event is InputEventKey and event.pressed:
		_release()
	elif event is InputEventMouseButton and event.pressed:
		_release()
	elif event is InputEventScreenTouch and event.pressed:
		_release()


func _release() -> void:
	_armed = false
	var p := _player()
	if p != null and p.has_method("release_cinematic"):
		p.call("release_cinematic")


func _player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")


## Every CAM_* marker the binder registered for the current chapter.
func _markers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var tree := get_tree()
	if tree == null:
		return out
	for n in tree.get_nodes_in_group("cinematic_camera"):
		if n is Node3D and (n as Node3D).is_inside_tree():
			out.append(n as Node3D)
	return out


## Find the marker that best reads as "this is where you are" for the opening.
func _pick_overview() -> Node3D:
	var marks := _markers()
	if marks.is_empty():
		return null
	for hint in OVERVIEW_HINTS:
		for m in marks:
			if m.name.contains(hint):
				return m
	return marks[0]


func _play_intro() -> void:
	var mark := _pick_overview()
	if mark == null:
		return
	var p := _player()
	if p == null or not p.has_method("push_cinematic"):
		return
	# Aim the shot at the pilgrim so the establishing frame has a subject —
	# markers carry a position but their authored rotation is not reliable.
	var xform := _aimed_at_player(mark, p as Node3D)
	p.call("push_cinematic", xform, intro_duration)
	_armed = true


## Build a look-at transform from `mark` toward the pilgrim, keeping the marker's
## height. Falls back to the marker's own basis if the two coincide.
func _aimed_at_player(mark: Node3D, player: Node3D) -> Transform3D:
	var from := mark.global_position
	var to := player.global_position + Vector3(0, 1.1, 0)
	if from.distance_to(to) < 0.6:
		return mark.global_transform
	var xf := Transform3D(Basis(), from)
	xf = xf.looking_at(to, Vector3.UP)
	return xf


# --------------------------------------------------------------------- public

## Play a named shot: ChapterCamera.shot("ThroneApproach", 3.0).
## `suffix` is matched against marker names, so "ThroneApproach" finds
## "CAM_ThroneApproach". Returns false when no such marker exists.
static func shot(suffix: String, duration: float = 3.2, aim_at_player: bool = true) -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var tree := loop as SceneTree
	var player := tree.get_first_node_in_group("player")
	if player == null or not player.has_method("push_cinematic"):
		return false
	for n in tree.get_nodes_in_group("cinematic_camera"):
		if not (n is Node3D):
			continue
		var m := n as Node3D
		if not m.name.contains(suffix):
			continue
		var xform := m.global_transform
		if aim_at_player and player is Node3D:
			var to: Vector3 = (player as Node3D).global_position + Vector3(0, 1.1, 0)
			if m.global_position.distance_to(to) > 0.6:
				xform = Transform3D(Basis(), m.global_position).looking_at(to, Vector3.UP)
		player.call("push_cinematic", xform, duration)
		return true
	return false


## True when this chapter authored any camera markers at all.
static func has_markers() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	return not (loop as SceneTree).get_nodes_in_group("cinematic_camera").is_empty()
