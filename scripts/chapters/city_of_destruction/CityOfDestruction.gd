extends ChapterBase
class_name CityOfDestruction
## Chapter 1. The doomed city. Talk to Evangelist to learn the way, weather the
## family's plea and Obstinate's mockery, then leave through the eastern gate.


func _build_chapter() -> void:
	setup_environment(
		Color(0.35, 0.12, 0.1),   # smoky red sky top
		Color(0.5, 0.25, 0.15),   # dim orange horizon
		0.55                       # low ambient: heavy, oppressive
	)
	make_ground(Vector2(40, 70), Color(0.28, 0.25, 0.22))

	# Player home and a few houses for a hemmed-in feeling.
	make_block(Vector3(5, 4, 5), Color(0.3, 0.26, 0.24), Vector3(-8, 2, 6))
	make_block(Vector3(5, 5, 5), Color(0.26, 0.23, 0.22), Vector3(8, 2.5, 8))
	make_block(Vector3(4, 3.5, 4), Color(0.3, 0.27, 0.25), Vector3(9, 1.75, -2))
	make_block(Vector3(4, 4, 4), Color(0.27, 0.24, 0.23), Vector3(-9, 2, -4))

	# Distant fire glow behind the city (the doom you are fleeing).
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 6, 28)
	glow.light_color = Color(1.0, 0.4, 0.2)
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	add_child(glow)
	make_decor(Vector3(40, 12, 1), Color(0.5, 0.15, 0.1), Vector3(0, 6, 34), 1.2)

	# The light of the gate, far ahead (east / forward = -Z).
	make_distant_light(Vector3(0, 5, -34))
	make_floating_label("Toward the Wicket Gate", Vector3(0, 3.5, -20), Color(1, 0.95, 0.7))

	# Eastern gate posts.
	make_block(Vector3(2, 6, 2), Color(0.4, 0.38, 0.35), Vector3(-4, 3, -19))
	make_block(Vector3(2, 6, 2), Color(0.4, 0.38, 0.35), Vector3(4, 3, -19))

	# NPCs
	make_npc("Your Family", Vector3(-6, 0, 5), Color(0.6, 0.45, 0.55), "wife_concern")
	make_npc("Evangelist", Vector3(0, 0, -4), Color(0.85, 0.8, 0.6), "evangelist_first_call")
	make_npc("Obstinate", Vector3(3, 0, -13), Color(0.45, 0.4, 0.35), "obstinate_confrontation")
	make_npc("Pliable", Vector3(-3, 0, -13), Color(0.6, 0.7, 0.5), "pliable_joins")

	spawn_player(Vector3(0, 1, 8))

	# Leave through the gate — but only once Evangelist has set you on the way.
	var _cb1 := func(_b):
		if not GameState.has_flag("talked_to_evangelist"):
			EventBus.toast("Do not flee blind. Speak with Evangelist and receive the way.")
			return
		GameState.set_flag("left_city", true)
		QuestManager.update_quest_progress("leave_city")
		EventBus.toast("You leave the City of Destruction behind, carrying the burden into mercy's road.")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -21), Vector3(10, 4, 2), _cb1, false)
