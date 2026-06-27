extends Node
class_name BossEncounter
## Glue between an imported boss arena and the existing combat system. Listens for
## the intro dialogue to end, then spawns a BossController at the ENEMY_ marker's
## position and starts the fight. Reuses BossController / ApollyonBoss / PlayerCombat
## / CombatHUD as-is. Built by ImportedSceneBinder from an ENEMY_* marker.

var intro_dialogue: String = "apollyon_encounter"
var spawn_pos: Vector3 = Vector3(0, 1, -18)
var _started: bool = false


func setup(p_intro: String, p_spawn: Vector3) -> void:
	intro_dialogue = p_intro
	spawn_pos = p_spawn
	if not EventBus.dialogue_ended.is_connected(_on_dialogue_ended):
		EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id != intro_dialogue or _started:
		return
	_started = true
	var bc := BossController.new()
	add_child(bc)
	bc.spawn_position = spawn_pos
	if bc.has_signal("fight_ended"):
		bc.fight_ended.connect(_on_victory)
	bc.start_boss_fight()


func _on_victory(_victory: bool) -> void:
	EventBus.toast("控告者的权势破碎了。山谷打开，更幽暗的路仍在前方。")
