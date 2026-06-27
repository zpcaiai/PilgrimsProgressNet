extends GlbChapter
class_name ValleyHumiliation
## Chapter 9 (finale of the vertical slice). Descend into the valley where
## Apollyon blocks the way. A short challenge, then the boss fight. Stand firm,
## pray, and answer with promises until his influence breaks.

var _combat: PlayerCombat = null
var _boss_controller: BossController = null
var _fight_started: bool = false


func _build_procedural() -> void:
	setup_environment(
		Color(0.18, 0.2, 0.16),
		Color(0.4, 0.18, 0.16),
		0.7
	)
	make_ground(Vector2(40, 60), Color(0.26, 0.32, 0.24))

	# Arena walls (natural rock) so you cannot simply flee the accuser.
	make_block(Vector3(1, 6, 44), Color(0.3, 0.28, 0.26), Vector3(-14, 3, -14))
	make_block(Vector3(1, 6, 44), Color(0.3, 0.28, 0.26), Vector3(14, 3, -14))
	make_block(Vector3(28, 6, 1), Color(0.3, 0.28, 0.26), Vector3(0, 3, -34))

	make_floating_label("降卑谷：站在恩典中", Vector3(0, 4.5, -28), Color(0.85, 0.6, 0.6))

	spawn_player(Vector3(0, 1, 10))

	# Arm the pilgrim for combat.
	_combat = PlayerCombat.new()
	player.add_child(_combat)
	if SpiritualStateManager.has_promise_key:
		_combat.promise_charge = 3
	add_child(CombatHUD.new())

	# Crossing into the valley summons Apollyon.
	var _cb1 := func(_b):
		if not GameState.has_flag("apollyon_met"):
			GameState.set_flag("apollyon_met", true)
			DialogueManager.start_dialogue("apollyon_encounter")
	make_trigger(Vector3(0, 1.5, -6), Vector3(28, 4, 2), _cb1, true)

	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == "apollyon_encounter" and not _fight_started:
		_fight_started = true
		_boss_controller = BossController.new()
		add_child(_boss_controller)
		_boss_controller.spawn_position = Vector3(0, 1, -18)
		_boss_controller.fight_ended.connect(_on_victory)
		_boss_controller.start_boss_fight()


func _on_victory(_v: bool) -> void:
	QuestManager.update_quest_progress("valley_humiliation")
	await get_tree().create_timer(2.0).timeout
	EventBus.toast("控告者的权势破碎了。山谷打开，更幽暗的路仍在前方。")
	await get_tree().create_timer(1.0).timeout
	ChapterManager.go_to_next_chapter()
