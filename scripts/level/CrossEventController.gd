extends Node
class_name CrossEventController
## Plays the Cross grace beat: the burden loosens, rolls down the PATH_BurdenRoll
## points toward the tomb, and grace is applied -- not earned by stats. Configured
## by ImportedSceneBinder with the burden prop and the ordered roll path.

var burden_node: Node3D = null
var path_points: Array = []
var _played: bool = false


func configure(p_burden: Node3D, p_points: Array) -> void:
	burden_node = p_burden
	path_points = p_points


func play() -> void:
	if _played:
		return
	_played = true
	EventBus.toast("You can carry it no farther. You come to the Cross with empty hands.")
	if is_instance_valid(burden_node) and path_points.size() >= 1:
		var tw := create_tween()
		tw.tween_interval(0.4)
		for p in path_points:
			tw.tween_property(burden_node, "global_position", p, 0.6)
		tw.tween_callback(_finish)
	else:
		_finish()


func _finish() -> void:
	if is_instance_valid(burden_node):
		burden_node.visible = false
	SpiritualStateManager.apply_cross_grace()
	# burden_fallen is the existing chapter-completion flag; the others are the
	# spec/event flags. Set all so either flag scheme closes the loop.
	for f in ["approached_cross", "burden_removed", "burden_fallen",
			"cross_grace_received", "mvp_completed"]:
		GameState.set_flag(f, true)
	QuestManager.update_quest_progress("reach_the_cross")
	AudioManager.play_sfx("blessing")
	EventBus.toast("The burden loosens where no hand touched it. It falls, and rolls away. The road continues beyond the hill.")
