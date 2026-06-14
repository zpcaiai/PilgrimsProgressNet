extends ChapterBase
class_name RiverOfDeath
## Chapter 15. The last crossing. There is no bridge. The deeper your fear, the
## harder the water pulls; faith — and Hopeful's steadying voice — carry you
## across. Reach the far bank.

var _river_player: PlayerController = null
var _tick: float = 0.0


func _build_chapter() -> void:
	setup_environment(
		Color(0.18, 0.22, 0.32),
		Color(0.6, 0.55, 0.55),
		0.7,
		true, Color(0.4, 0.45, 0.55), 0.03
	)
	# Near bank, river, far bank.
	make_ground(Vector2(30, 18), Color(0.32, 0.4, 0.3), Vector3(0, 0, 10))
	make_ground(Vector2(30, 18), Color(0.32, 0.4, 0.3), Vector3(0, 0, -24))

	# The water (visual + crossing zone).
	var water := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(30, 0.4, 26)
	water.mesh = bm
	water.position = Vector3(0, -0.1, -7)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.35, 0.55, 0.7)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.metallic = 0.3
	wmat.roughness = 0.2
	water.material_override = wmat
	add_child(water)
	# Shallow floor so the player can walk across.
	make_ground(Vector2(30, 26), Color(0.25, 0.3, 0.35), Vector3(0, -0.4, -7))

	# Crossing zone.
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 1
	zone.monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 3, 26)
	col.shape = box
	zone.add_child(col)
	zone.position = Vector3(0, 1, -7)
	zone.body_entered.connect(func(b):
		if b is PlayerController:
			_river_player = b
	)
	zone.body_exited.connect(func(b):
		if b == _river_player and _river_player != null:
			_river_player.terrain_multiplier = 1.0
			_river_player = null
	)
	add_child(zone)

	make_distant_light(Vector3(0, 8, -34), Color(1.0, 0.95, 0.7))
	make_floating_label("The far bank of welcome", Vector3(0, 4, -26), Color(1.0, 0.95, 0.75))
	make_floating_label("There is no bridge — only faith receiving mercy", Vector3(0, 3, 6), Color(0.8, 0.8, 0.85))

	spawn_player(Vector3(0, 1, 14))

	make_trigger(Vector3(0, 1.5, -22), Vector3(20, 4, 2), func(_b):
		GameState.set_flag("crossed_river", true)
		QuestManager.update_quest_progress("cross_river")
		EventBus.toast("Your feet find the far bank. Even the last river could not keep grace out.")
		_advance_after_delay()
	, false)


func _process(delta: float) -> void:
	if _river_player == null:
		return
	var fear := float(SpiritualStateManager.fear)
	var faith := float(SpiritualStateManager.faith)
	var child := GameState.is_child_mode()
	# Fear pulls you down; faith steadies your footing. Child mode keeps a higher
	# floor so the crossing is never frightening.
	var floor_mult := 0.7 if child else 0.4
	var slow := clampf(1.0 - fear * 0.004 + faith * 0.002, floor_mult, 1.0)
	_river_player.terrain_multiplier = slow
	_tick += delta
	if _tick >= 1.5:
		_tick = 0.0
		if faith >= fear or child:
			SpiritualStateManager.apply_effects({"fear": -3, "hope": 2})
		else:
			SpiritualStateManager.apply_effects({"fear": 4, "despair": 3})
			EventBus.toast("The water rises with fear. Listen to Hopeful, and receive faith for the next step.")
