extends ChapterBase
class_name ValleyShadowDeath
## Chapter 10. A pitch-dark, narrow path. Your lantern of faith lights only a
## small circle; fear shrinks it, faith and the lanterns of the Word restore it.
## Whispers from the dark raise fear. Keep to the path and reach the dawn.


func _build_chapter() -> void:
	setup_environment(
		Color(0.02, 0.02, 0.05),
		Color(0.06, 0.05, 0.1),
		0.12,
		true, Color(0.05, 0.05, 0.1), 0.06
	)
	make_ground(Vector2(8, 90), Color(0.12, 0.12, 0.15))
	# Cliff walls hemming the narrow way.
	make_block(Vector3(1, 8, 90), Color(0.08, 0.08, 0.1), Vector3(-4.5, 4, -20))
	make_block(Vector3(1, 8, 90), Color(0.08, 0.08, 0.1), Vector3(4.5, 4, -20))

	spawn_player(Vector3(0, 1, 12))
	var lantern := PlayerLight.new()
	player.add_child(lantern)

	# Combat is optional here: two weak fear-shades haunt the path. Stand firm
	# (L), pray (P), or simply press on past them to the dawn.
	var pc := PlayerCombat.new()
	player.add_child(pc)
	if SpiritualStateManager.has_promise_key:
		pc.promise_charge = 2
	add_child(CombatHUD.new())
	_spawn_fear_shade(Vector3(1.5, 1, -4))
	_spawn_fear_shade(Vector3(-1.5, 1, -22))

	# Whispers from the dark — each raises fear once.
	_whisper(Vector3(0, 1.5, 2), "A voice hisses: 'The dark is telling the truth. You will not finish.'")
	_whisper(Vector3(0, 1.5, -10), "Something laughs in the dark: 'Turn back while fear still sounds wise.'")
	_whisper(Vector3(0, 1.5, -26), "A whisper presses close: 'No one sees you here. No one keeps you.'")

	# Lanterns of the Word — restore your light.
	_lantern(Vector3(-2.5, 0, -6), lantern)
	_lantern(Vector3(2.5, 0, -20), lantern)
	_lantern(Vector3(-2.5, 0, -32), lantern)

	# The dawn ahead.
	make_distant_light(Vector3(0, 5, -48), Color(1.0, 0.9, 0.7))
	make_floating_label("Toward the dawn you cannot yet see", Vector3(0, 3, -40), Color(0.8, 0.8, 0.7))

	make_trigger(Vector3(0, 1.5, -44), Vector3(8, 4, 2), func(_b):
		GameState.set_flag("crossed_shadow", true)
		QuestManager.update_quest_progress("cross_shadow")
		EventBus.toast("The path widens, and grey dawn proves the dark was not lord.")
		_advance_after_delay()
	, false)


func _spawn_fear_shade(pos: Vector3) -> void:
	var e := SymbolicEnemy.new()
	e.load_from_data("fear_shade")
	e.influence = 32.0
	e.max_influence = 32.0
	e.move_speed = 2.2
	add_child(e)
	e.global_position = pos


func _whisper(pos: Vector3, text: String) -> void:
	make_trigger(pos, Vector3(8, 4, 2), func(_b):
		SpiritualStateManager.apply_effects({"fear": 12})
		EventBus.toast(text)
	, true)


func _lantern(pos: Vector3, lantern: PlayerLight) -> void:
	make_interactable(pos, "Read the lantern of the Word",
		func(_p):
			lantern.add_boost(4.0)
			SpiritualStateManager.apply_effects({"fear": -10, "faith": 5})
			EventBus.toast("The Word steadies the lamp, and the next step appears.")
		, null, Color(1.0, 0.9, 0.6), 1.5, 1.3, true)
