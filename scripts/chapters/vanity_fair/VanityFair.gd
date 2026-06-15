extends ChapterBase
class_name VanityFair
## Chapter 11. A loud, glittering market that sells everything but peace. Each
## stall offers a real choice: BUY (pride/deception, a vanity token that weighs
## on you) or REFUSE (discernment/perseverance). Hopeful joins you here. The far
## gate notices what you are still carrying.


var _active_ware: String = ""
var _active_buy_effects: Dictionary = {}


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

	# Temptation stalls — each one a buy/refuse choice.
	_stall(Vector3(-8, 0, -6), "the Crown of Honour", Color(0.9, 0.8, 0.2), {"pride": 12, "humility": -6})
	_stall(Vector3(8, 0, -6), "the Cup of Pleasures", Color(0.8, 0.2, 0.4), {"deception": 12, "watchfulness": -6})
	_stall(Vector3(-8, 0, -16), "the Cloak of Reputation", Color(0.5, 0.3, 0.9), {"pride": 10, "discernment": -5})
	_stall(Vector3(8, 0, -16), "the Glass of Flattery", Color(0.3, 0.8, 0.9), {"deception": 10, "humility": -5})

	# Hopeful, a true companion in the crowd.
	make_npc("Hopeful", Vector3(0, 0, -22), Color(0.55, 0.8, 0.7), "hopeful_joins")

	make_floating_label("The far gate beyond the noise", Vector3(0, 3, -30), Color(0.85, 0.85, 0.7))
	make_wayside_chapel(Vector3(-11, 0, -26), "vanity", {"discernment": 6, "pride": -6, "hope": 4}, "Behind the stalls, a chapel the fair forgot. Here peace is not for sale; it is given.")

	spawn_player(Vector3(0, 1, 10))

	EventBus.dialogue_ended.connect(_on_dialogue_ended)

	make_trigger(Vector3(0, 1.5, -32), Vector3(16, 4, 2), func(_b):
		if not GameState.has_flag("hopeful_joined"):
			EventBus.toast("Do not leave alone. Find Hopeful in the crowd.")
			return
		_leave_fair()
	, false)


func _leave_fair() -> void:
	GameState.set_flag("left_vanity", true)
	QuestManager.update_quest_progress("pass_vanity_fair")
	# The gate notices the vanity you are still carrying.
	var bought := GameState.get_item_count("vanity_token")
	if bought >= 2:
		SpiritualStateManager.apply_effects({"pride": 4, "weariness": 4})
		EventBus.toast("You leave laden with baubles; Hopeful says nothing, but his eyes are sad.")
	elif bought == 1:
		EventBus.toast("One trinket still jingles in your pocket. The road will quiet it soon enough.")
	else:
		EventBus.toast("You and Hopeful leave the fair with peace still unsold.")
	_advance_after_delay()


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "hopeful_joins" and GameState.has_flag("hopeful_joined"):
		if not GameState.has_companion("hopeful"):
			GameState.add_companion("hopeful")
			if companion == null:
				spawn_companion("Hopeful", Color(0.55, 0.8, 0.7))
	elif dialogue_id == "vanity_stall":
		# A purchase applies that specific stall's extra cost.
		if GameState.has_flag("vanity_bought_pending"):
			GameState.set_flag("vanity_bought_pending", false)
			SpiritualStateManager.apply_effects(_active_buy_effects)
			EventBus.toast("You buy " + _active_ware + ". Its shine is loud; its weight is quiet.")
			AudioManager.play_sfx("vanity_buy")
			if is_instance_valid(player):
				player.refresh_vanity()


func _stall(pos: Vector3, ware: String, color: Color, buy_effects: Dictionary) -> void:
	make_decor(Vector3(2.5, 2.5, 2.5), color, pos + Vector3(0, 1.25, 0), 0.6)
	make_floating_label(ware, pos + Vector3(0, 3, 0), color)
	make_interactable(pos + Vector3(0, 0, 1.6), "Approach " + ware,
		func(_p):
			_active_ware = ware
			_active_buy_effects = buy_effects
			DialogueManager.start_dialogue("vanity_stall")
		, null, color.darkened(0.2), 0.4, 1.6, false)
