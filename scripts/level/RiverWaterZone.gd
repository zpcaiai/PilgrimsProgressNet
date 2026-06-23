extends Area3D
class_name RiverWaterZone
## The wet stretch of the River of Death. While the pilgrim is inside it he is
## submerged to the waist and swims (PlayerController.set_swimming); the water
## pulls according to fear vs. faith — deep fear drags him almost to a stop,
## faith steadies his footing. The crossing is never lethal: when faith leads,
## fear eases and hope rises. Bound by ImportedSceneBinder from COL_RiverWater.
## (RiverDepthSystem still drives the separate depth-pressure meter + Hopeful's
## nudge; this zone owns the swim posture and the wade slowdown.)

var _player: PlayerController = null
var _tick: float = 0.0


func setup(size: Vector3) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(b: Node) -> void:
	if b is PlayerController:
		_player = b
		b.set_swimming(true)


func _on_exited(b: Node) -> void:
	if b == _player and _player != null:
		_player.set_swimming(false)
		_player.terrain_multiplier = 1.0
		_player = null


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var fear := float(SpiritualStateManager.fear)
	var faith := float(SpiritualStateManager.faith)
	var child := GameState.is_child_mode()
	# Fear pulls you down; faith steadies your footing. Child mode keeps a higher
	# floor so the crossing is never frightening.
	var floor_mult := 0.7 if child else 0.4
	var slow := clampf(1.0 - fear * 0.004 + faith * 0.002, floor_mult, 1.0)
	_player.terrain_multiplier = slow
	_tick += delta
	if _tick >= 1.5:
		_tick = 0.0
		if faith >= fear or child:
			SpiritualStateManager.apply_effects({"fear": -3, "hope": 2})
		else:
			SpiritualStateManager.apply_effects({"fear": 4, "despair": 3})
			EventBus.toast("水随惧怕上涨。听何普的话，领受信心，再迈一步。(The water rises with fear. Hear Hopeful; take faith for the next step.)")
