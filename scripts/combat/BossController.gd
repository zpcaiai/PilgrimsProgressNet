extends Node3D
class_name BossController
## Orchestrates a boss encounter: spawns the boss, reports victory, and emits a
## signal the arena/chapter can react to. Kept thin so specific bosses live in
## their own scripts.

signal fight_started()
signal fight_ended(victory: bool)

var boss_scene_script: GDScript = null
var spawn_position: Vector3 = Vector3(0, 1, -8)
var _boss: SymbolicEnemy = null
var _started: bool = false


func start_boss_fight() -> void:
	if _started:
		return
	_started = true
	_boss = ApollyonBoss.new()
	add_child(_boss)
	_boss.global_position = spawn_position
	if _boss.has_signal("boss_defeated"):
		_boss.connect("boss_defeated", _on_victory)
	EventBus.toast("Apollyon blocks the valley. Stand in grace, not in yourself.")
	fight_started.emit()


func _on_victory() -> void:
	fight_ended.emit(true)


func is_active() -> bool:
	return _started and is_instance_valid(_boss)
