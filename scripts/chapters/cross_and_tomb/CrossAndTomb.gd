extends ChapterBase
class_name CrossAndTomb
## Chapter 5. The climax. Climb the hill to the Cross. The burden loosens,
## falls, and rolls into the open tomb. Grace is given freely — not earned by
## stats. The road continues from here into formation, combat, endurance, and hope.

var _triggered: bool = false
var _light: OmniLight3D


func _build_chapter() -> void:
	setup_environment(
		Color(0.55, 0.7, 0.9),     # clear sunrise blue
		Color(0.98, 0.85, 0.6),    # warm gold horizon
		1.1
	)
	make_ground(Vector2(50, 60), Color(0.35, 0.5, 0.32))

	# A gentle hill leading up to the Cross (forward = -Z).
	make_block(Vector3(20, 2, 8), Color(0.4, 0.52, 0.34), Vector3(0, 0.5, -12))
	make_block(Vector3(14, 3, 6), Color(0.42, 0.54, 0.36), Vector3(0, 1.0, -16))

	# The Cross.
	make_block(Vector3(0.6, 6, 0.6), Color(0.45, 0.35, 0.25), Vector3(0, 4.5, -18))
	make_block(Vector3(3.2, 0.6, 0.6), Color(0.45, 0.35, 0.25), Vector3(0, 6.0, -18))

	# The open tomb, to the side.
	make_block(Vector3(3, 3, 3), Color(0.3, 0.3, 0.32), Vector3(7, 1.5, -18))
	make_decor(Vector3(1.6, 1.8, 0.3), Color(0.05, 0.05, 0.05), Vector3(6.3, 1.2, -16.6))

	# Soft light at the Cross, brightened when the burden falls.
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 5, -18)
	_light.light_color = Color(1.0, 0.95, 0.78)
	_light.light_energy = 2.0
	_light.omni_range = 25.0
	add_child(_light)

	make_floating_label("The Cross", Vector3(0, 7.5, -18), Color(1, 0.97, 0.8))

	spawn_player(Vector3(0, 1, 12))

	make_trigger(Vector3(0, 2.5, -13), Vector3(12, 5, 2), func(_b): _begin_cross_event(), true)


func _begin_cross_event() -> void:
	if _triggered:
		return
	_triggered = true
	EventBus.player_control_locked.emit(true)

	# Spawn a burden that rolls from the pilgrim down into the tomb.
	var burden := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.5)
	burden.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.2, 0.18)
	burden.material_override = mat
	add_child(burden)
	burden.global_position = player.global_position + Vector3(0, 1.1, 0)

	await get_tree().create_timer(0.6).timeout

	# When despair is overwhelming, the burden trembles but will not fall until the
	# pilgrim names the truth. Grace is still not earned — confession only precedes it.
	if SpiritualStateManager.despair >= 85:
		EventBus.toast("The burden trembles at the Cross, but does not fall — first, name your true state.")
		await get_tree().create_timer(1.8).timeout
		EventBus.toast("\"What I carry is too heavy; I cannot set it down myself. Have mercy.\"")
		await get_tree().create_timer(2.0).timeout
		EventBus.toast("And as the words are spoken, the burden loosens.")
		await get_tree().create_timer(0.9).timeout

	# Grace: the burden falls regardless of the pilgrim's strength.
	make_light_burst(Vector3(0, 1.5, -18), Color(1.0, 0.96, 0.75), 64)
	SpiritualStateManager.apply_cross_grace()
	GameState.set_flag("burden_fallen", true)
	GameState.set_flag("mvp_completed", true)
	QuestManager.update_quest_progress("reach_the_cross")
	EventBus.toast("Your burden loosens, falls, and is answered by grace.")

	# Roll the burden into the tomb and brighten the hill.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burden, "global_position", Vector3(6.3, 0.6, -16.6), 1.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(burden, "rotation", Vector3(TAU, TAU * 0.5, 0), 1.6)
	tween.tween_property(_light, "light_energy", 6.0, 1.6)
	tween.chain().tween_callback(func():
		if is_instance_valid(burden):
			burden.queue_free()
	)

	await get_tree().create_timer(2.5).timeout
	EventBus.toast("The Cross is not the end of the road; it is the mercy that makes the road possible.")
	await get_tree().create_timer(1.5).timeout
	ChapterManager.go_to_next_chapter()
