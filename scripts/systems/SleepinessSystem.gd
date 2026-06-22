extends Node
class_name SleepinessSystem
## Drives the Enchanted Ground "sleepiness" meter. Standing still raises it;
## moving, low watchfulness changes the rate; the Shepherd Map helps. At 100 the
## pilgrim dozes (non-lethal): a little ground is lost and, if Hopeful travels
## with you, he wakes you. Added by GlbChapter for enchanted_ground.

var _player: Node3D = null
var _accum: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _doze_cd: float = 0.0


func _ready() -> void:
	GameState.set_temporary_meter("sleepiness", 0)
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_last_pos = _player.global_position


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _doze_cd > 0.0:
		_doze_cd -= delta
	_accum += delta
	if _accum < 1.0:
		return
	_accum = 0.0
	var moved := _player.global_position.distance_to(_last_pos)
	_last_pos = _player.global_position
	var s := GameState.get_temporary_meter("sleepiness")
	if moved > 0.5:
		s -= 6
	else:
		s += 5 + int(max(0, 20 - SpiritualStateManager.watchfulness) / 5.0)
	if SpiritualStateManager.has_shepherd_map:
		s -= 2
	GameState.set_temporary_meter("sleepiness", s)
	if GameState.get_temporary_meter("sleepiness") >= 100 and _doze_cd <= 0.0:
		_doze_cd = 12.0
		GameState.set_temporary_meter("sleepiness", 45)
		SpiritualStateManager.apply_effects({"watchfulness": -5})
		if GameState.has_companion("hopeful"):
			SpiritualStateManager.apply_effects({"hope": 5, "watchfulness": 8, "weariness": -5})
			EventBus.toast("You doze... Hopeful shakes you awake. 'Not here, friend. Keep walking, keep talking.'")
		else:
			EventBus.toast("Sleep takes you for a moment, and you lose ground. Keep moving.")
