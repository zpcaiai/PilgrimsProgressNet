extends ChapterBase
class_name CombatTestArena
## A standalone arena for testing symbolic combat. Run this scene directly in
## Godot to try fear/shame/despair enemies and the Apollyon boss. Not part of
## the main story route.

var _boss_controller: BossController = null


func _build_chapter() -> void:
	setup_environment(
		Color(0.3, 0.32, 0.28),
		Color(0.5, 0.3, 0.3),
		0.7
	)
	make_ground(Vector2(50, 50), Color(0.3, 0.38, 0.3))
	make_floating_label("Combat Test Arena", Vector3(0, 4, -18), Color(1, 0.9, 0.8))

	spawn_player(Vector3(0, 1, 8))

	# Give the pilgrim some footing to fight from.
	SpiritualStateManager.reset_for_new_game()
	SpiritualStateManager.set_state("faith", 40)
	SpiritualStateManager.set_state("hope", 40)
	SpiritualStateManager.set_state("perseverance", 40)

	var pc := PlayerCombat.new()
	player.add_child(pc)

	# Symbolic enemies.
	_spawn_enemy("fear_shade", Vector3(-5, 1, -4))
	_spawn_enemy("shame_accuser", Vector3(5, 1, -6))
	_spawn_enemy("despair_wraith", Vector3(0, 1, -10))

	# A promise pickup to recharge.
	var _cb1 := func(_p):
		var c := get_tree().get_nodes_in_group("player_combat")
		if c.size() > 0:
			c[0].promise_charge = min(3, c[0].promise_charge + 1)
		EventBus.toast("You take up a promise (charge +1).")
	make_interactable(Vector3(-8, 0, 2), "Take up a promise",
		_cb1, null, Color(0.9, 0.85, 0.5), 1.5, 1.2, false)

	# Summon the boss.
	make_interactable(Vector3(8, 0, 2), "Summon Apollyon",
		func(_p): _start_boss(), null, Color(0.6, 0.15, 0.15), 1.0, 1.2, true)

	# Self-sufficient UI when run standalone.
	add_child(HUD.new())
	add_child(CombatHUD.new())


func _spawn_enemy(id: String, pos: Vector3) -> void:
	var e := SymbolicEnemy.new()
	e.load_from_data(id)
	add_child(e)
	e.global_position = pos


func _start_boss() -> void:
	if _boss_controller != null:
		return
	_boss_controller = BossController.new()
	add_child(_boss_controller)
	_boss_controller.spawn_position = Vector3(0, 1, -12)
	_boss_controller.fight_ended.connect(func(_v): EventBus.toast("The valley is quiet. Victory."))
	_boss_controller.start_boss_fight()
