extends Area3D
class_name HazardZone
## Generic tick-effect volume. While the player stands inside, it applies a
## dictionary of spiritual effects every `tick_interval` seconds and (optionally)
## raises a flag and shows an occasional inner-voice toast. Subclasses (FearZone,
## ShameFieldZone, ...) just preset the defaults. Built by ImportedSceneBinder
## from a COL_* box in the imported GLB, so the box size is the zone extent.

var effects_per_tick: Dictionary = {"fear": 2}
var tick_interval: float = 2.5
var toast_line: String = ""
var enter_flag: String = ""
var _player: Node = null
var _accum: float = 0.0
var _ticks: int = 0


func setup(size: Vector3, effects: Dictionary = {}, interval: float = -1.0,
		line: String = "", flag: String = "") -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	if not effects.is_empty():
		effects_per_tick = effects
	if interval > 0.0:
		tick_interval = interval
	toast_line = line
	enter_flag = flag
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	if enter_flag != "" and not GameState.has_flag(enter_flag):
		GameState.set_flag(enter_flag, true)
	_on_player_entered()


## Hook for subclasses (e.g. start a dialogue or VFX). Default: nothing.
func _on_player_entered() -> void:
	pass


func _on_exit(body: Node) -> void:
	if body == _player:
		_player = null
		_accum = 0.0
		_ticks = 0


func _process(delta: float) -> void:
	if _player == null:
		return
	_accum += delta
	if _accum >= tick_interval:
		_accum = 0.0
		SpiritualStateManager.apply_effects(effects_per_tick)
		_ticks += 1
		if toast_line != "" and _ticks % 2 == 1:
			EventBus.toast(toast_line)
