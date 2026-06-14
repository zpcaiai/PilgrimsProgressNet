extends ChapterBase
class_name VanityFair
## Chapter 11. A loud, glittering market that sells everything but peace. Stalls
## tempt you; buying feeds pride and deception, refusing builds discernment.
## Hopeful, who admires your refusal, joins you here. Leave by the far gate.


func _build_chapter() -> void:
	setup_environment(
		Color(0.3, 0.1, 0.3),
		Color(0.9, 0.5, 0.2),
		0.9
	)
	make_ground(Vector2(30, 60), Color(0.4, 0.3, 0.4))

	# Garish stall lights.
	var colors := [Color(1, 0.2, 0.3), Color(0.3, 1, 0.4), Color(0.9, 0.8, 0.2), Color(0.6, 0.3, 1)]
	for i in range(4):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-9 + i * 6, 4, -8 - (i % 2) * 8)
		lamp.light_color = colors[i]
		lamp.light_energy = 2.5
		lamp.omni_range = 12.0
		add_child(lamp)

	# Temptation stalls.
	_stall(Vector3(-8, 0, -6), "the Crown of Honour", Color(0.9, 0.8, 0.2), {"pride": 12, "humility": -6})
	_stall(Vector3(8, 0, -6), "the Cup of Pleasures", Color(0.8, 0.2, 0.4), {"deception": 12, "watchfulness": -6})
	_stall(Vector3(-8, 0, -16), "the Cloak of Reputation", Color(0.5, 0.3, 0.9), {"pride": 10, "discernment": -5})
	_stall(Vector3(8, 0, -16), "the Glass of Flattery", Color(0.3, 0.8, 0.9), {"deception": 10, "humility": -5})

	# Hopeful, a true companion in the crowd.
	make_npc("Hopeful", Vector3(0, 0, -22), Color(0.55, 0.8, 0.7), "hopeful_joins")

	make_floating_label("The far gate beyond the noise", Vector3(0, 3, -30), Color(0.85, 0.85, 0.7))
	spawn_player(Vector3(0, 1, 10))

	EventBus.dialogue_ended.connect(_on_dialogue_ended)

	make_trigger(Vector3(0, 1.5, -32), Vector3(16, 4, 2), func(_b):
		if not GameState.has_flag("hopeful_joined"):
			EventBus.toast("Do not leave alone. Find Hopeful in the crowd.")
			return
		GameState.set_flag("left_vanity", true)
		QuestManager.update_quest_progress("pass_vanity_fair")
		EventBus.toast("You and Hopeful leave the fair with peace still unsold.")
		_advance_after_delay()
	, false)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "hopeful_joins" and GameState.has_flag("hopeful_joined"):
		if not GameState.has_companion("hopeful"):
			GameState.add_companion("hopeful")
			if companion == null:
				spawn_companion("Hopeful", Color(0.55, 0.8, 0.7))


func _stall(pos: Vector3, ware: String, color: Color, _buy_effects: Dictionary) -> void:
	make_decor(Vector3(2.5, 2.5, 2.5), color, pos + Vector3(0, 1.25, 0), 0.6)
	make_floating_label(ware, pos + Vector3(0, 3, 0), color)
	make_interactable(pos + Vector3(0, 0, 1.6), "Refuse " + ware,
		func(_p):
			# Refusing is the virtuous interaction the player triggers.
			SpiritualStateManager.apply_effects({"discernment": 5, "perseverance": 3, "humility": 2})
			EventBus.toast("You turn from " + ware + ". Its shine fades when peace is worth more.")
		, null, color.darkened(0.2), 0.4, 1.4, true)
