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

	# A little neighbourhood of cottages, hemming the road in (off the path).
	PropKit.cottage(self, Vector3(9, 0, 8), Vector3(5, 3.2, 5), Color(0.5, 0.43, 0.4), Color(0.33, 0.23, 0.17))
	PropKit.cottage(self, Vector3(10, 0, -2), Vector3(4.5, 3.0, 4.5), Color(0.46, 0.4, 0.37), Color(0.3, 0.21, 0.16))
	PropKit.cottage(self, Vector3(-10, 0, -4), Vector3(4.5, 3.2, 4.5), Color(0.48, 0.42, 0.38), Color(0.32, 0.22, 0.16))

	# Distant fire glow behind the city (the doom you are fleeing).
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 6, 28)
	glow.light_color = Color(1.0, 0.4, 0.2)
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	add_child(glow)

	# The light of the gate, far ahead (east / forward = -Z).
	make_distant_light(Vector3(0, 5, -34))
	make_floating_label("Toward the Wicket Gate", Vector3(0, 3.5, -20), Color(1, 0.95, 0.7))

	# Eastern gate posts.
	make_block(Vector3(2, 6, 2), Color(0.4, 0.38, 0.35), Vector3(-4, 3, -19))
	make_block(Vector3(2, 6, 2), Color(0.4, 0.38, 0.35), Vector3(4, 3, -19))

	# The pilgrim's family stays behind in their home — seen in the lit doorway.
	_build_family_house(Vector3(-7, 0, 4))

	# NPCs
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


## The family home: a cottage with the family (your_family.webp) standing in the
## warmly-lit doorway, staying behind. Still interactable for the wife's plea.
func _build_family_house(pos: Vector3) -> void:
	PropKit.cottage(self, pos, Vector3(5, 3.2, 5), Color(0.5, 0.42, 0.4), Color(0.32, 0.22, 0.16))

	# Drawing near the family's home eases the heart a little (once): the warmth
	# of what you are leaving behind steadies despair and weariness.
	var family_solace := func(_b: Node) -> void:
		SpiritualStateManager.apply_effects({"despair": -5, "weariness": -5})
		EventBus.toast("Home's familiar warmth steadies you — despair and weariness ease a little.")
	make_trigger(pos + Vector3(0, 1.0, 2.0), Vector3(7, 3, 7), family_solace)

	# The family, seen inside the doorway. Falls back to the old greybox NPC if
	# the figure art is missing, so the plea always works.
	var fig := AssetLib.figure("Your Family")
	if fig == null:
		make_npc("Your Family", pos + Vector3(0, 0, 1.0), Color(0.6, 0.45, 0.55), "wife_concern")
		return
	var spr := CharacterBillboard.make(fig, 1.9)
	spr.position = Vector3(pos.x, 0.95, pos.z + 1.0)
	add_child(spr)

	# Warm hearth light inside so they are clearly visible.
	var hearth := OmniLight3D.new()
	hearth.position = pos + Vector3(0, 1.5, -0.4)
	hearth.light_color = Color(1.0, 0.78, 0.48)
	hearth.light_energy = 2.4
	hearth.omni_range = 6.5
	add_child(hearth)

	# Interaction at the door: the family begs the pilgrim to stay.
	var area := Interactable.new()
	area.name = "YourFamily"
	area.position = pos + Vector3(0, 0, 3.0)
	area.prompt = "Dear My Love求你别走"
	area.interact_callback = func(_p): DialogueManager.start_dialogue("wife_concern")
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	col.position = Vector3(0, 0.9, 0)
	area.add_child(col)
	add_child(area)
	make_floating_label("Dear My Love", pos + Vector3(0, 3.4, 1.0), Color(0.85, 0.7, 0.7))
