extends ChapterBase
class_name CelestialCity
## Chapter 16. Journey's end. A shining road climbs to the gate of the City.
## Walk up, and the pilgrimage is complete.

var _done: bool = false


func _build_chapter() -> void:
	setup_environment(
		Color(0.6, 0.78, 1.0),
		Color(1.0, 0.95, 0.78),
		1.3
	)
	make_ground(Vector2(30, 60), Color(0.55, 0.6, 0.5))

	# A golden road rising to the gate.
	for i in range(6):
		var z := 0.0 - i * 5.0
		make_decor(Vector3(6, 0.1, 5), Color(1.0, 0.92, 0.65), Vector3(0, 0.06, z), 0.6)

	# The gate and its great light.
	make_block(Vector3(2, 9, 2), Color(0.95, 0.9, 0.7), Vector3(-4, 4.5, -30), 0.4)
	make_block(Vector3(2, 9, 2), Color(0.95, 0.9, 0.7), Vector3(4, 4.5, -30), 0.4)
	make_block(Vector3(10, 2, 1), Color(1.0, 0.95, 0.75), Vector3(0, 9, -30), 0.6)
	var gate_light := OmniLight3D.new()
	gate_light.position = Vector3(0, 6, -32)
	gate_light.light_color = Color(1.0, 0.97, 0.8)
	gate_light.light_energy = 8.0
	gate_light.omni_range = 40.0
	add_child(gate_light)

	make_floating_label("The Celestial City", Vector3(0, 11, -30), Color(1.0, 0.97, 0.82))

	# Those who walked with you, waiting at the gate to welcome you in.
	make_npc("Evangelist", Vector3(-3, 0, -27), Color(0.85, 0.82, 0.7))
	make_npc("Shepherd", Vector3(3, 0, -27), Color(0.7, 0.78, 0.6))
	if GameState.has_companion("hopeful"):
		make_npc("Hopeful", Vector3(0, 0, -25), Color(0.55, 0.8, 0.7))

	spawn_player(Vector3(0, 1, 14))

	make_trigger(Vector3(0, 1.5, -27), Vector3(10, 5, 2), func(_b): _arrive(), true)


func _arrive() -> void:
	if _done:
		return
	_done = true
	EventBus.player_control_locked.emit(true)
	make_light_burst(Vector3(0, 2, -28), Color(1.0, 0.97, 0.82), 90)
	GameState.set_flag("entered_city", true)
	QuestManager.update_quest_progress("enter_celestial_city")
	ChapterManager.complete_chapter("celestial_city")
	EventBus.toast("The gates open, and those who walked with you turn to welcome you home.")
	await get_tree().create_timer(2.6).timeout
	if GameState.has_flag("interpreter_full"):
		EventBus.toast("The Interpreter is among them: 'You looked at every lamp in my house. Now you stand in the Light they were lit from.'")
		await get_tree().create_timer(3.0).timeout
	if GameState.has_flag("chapel_pilgrim"):
		EventBus.toast("A Shepherd smiles: 'You knelt at the wayside chapels no one saw you enter. Heaven kept every one. Welcome.'")
		await get_tree().create_timer(3.0).timeout
	EventBus.toast("You did not arrive by your own strength, but were carried by grace — every step held.")
	await get_tree().create_timer(3.0).timeout
	EventBus.toast("The burden is long gone. The journey is finished. Enter into rest.")
	await get_tree().create_timer(2.8).timeout
	EventBus.demo_completed.emit()
