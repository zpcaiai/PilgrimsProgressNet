extends ChapterBase
class_name HillDifficulty
## Chapter 7. From an open base, three corridors diverge. Danger and Destruction
## look easier but end badly; the narrow middle way is steep and slow but true.
## A rest arbor on the middle path tempts you to linger and grow drowsy.

var _arbor_player: PlayerController = null
var _arbor_time: float = 0.0
var _arbor_warned: bool = false


func _build_chapter() -> void:
	setup_environment(
		Color(0.45, 0.55, 0.7),
		Color(0.8, 0.78, 0.6),
		0.95
	)
	make_ground(Vector2(46, 80), Color(0.42, 0.46, 0.34))

	# Signposts at the three corridor mouths (the base, z > 0, is open so you
	# can walk to any of them and choose).
	make_floating_label("Danger →", Vector3(-12, 2.6, -1), Color(0.6, 0.7, 0.95))
	make_floating_label("Difficulty (true)", Vector3(0, 2.6, -1), Color(0.95, 0.95, 0.8))
	make_floating_label("← Destruction", Vector3(12, 2.6, -1), Color(0.95, 0.7, 0.5))

	# Dividing walls between the three corridors (only for z < 0, so the base
	# plaza stays open for the choice).
	make_block(Vector3(1, 4, 34), Color(0.4, 0.42, 0.36), Vector3(-6, 2, -17))
	make_block(Vector3(1, 4, 34), Color(0.4, 0.42, 0.36), Vector3(6, 2, -17))
	# Outer walls.
	make_block(Vector3(1, 4, 34), Color(0.36, 0.38, 0.32), Vector3(-18, 2, -17))
	make_block(Vector3(1, 4, 34), Color(0.36, 0.38, 0.32), Vector3(18, 2, -17))

	# Left: Danger — a dark dead end that breeds deception.
	make_block(Vector3(11, 4, 1), Color(0.3, 0.34, 0.4), Vector3(-12, 2, -26))
	make_trigger(Vector3(-12, 1.5, -22), Vector3(10, 4, 2), func(_b):
		SpiritualStateManager.apply_effects({"deception": 10, "discernment": -4})
		EventBus.toast("Danger hides its end in thorns and shadow. Turn back to the true path.")
	, true)

	# Right: Destruction — wide, comfortable, ending in a sudden drop.
	make_block(Vector3(11, 4, 1), Color(0.5, 0.4, 0.34), Vector3(12, 2, -26))
	make_trigger(Vector3(12, 1.5, -22), Vector3(10, 4, 2), func(_b):
		SpiritualStateManager.apply_effects({"despair": 12, "weariness": 8})
		EventBus.toast("Destruction stays wide until it breaks beneath you. Stagger back to truth.")
	, true)

	# Middle: the true, steep way — slow going, with a tempting rest arbor.
	_add_steep_zone(Vector3(0, 1, -14), Vector3(10, 2, 22))
	_build_rest_arbor(Vector3(0, 0, -22))

	make_distant_light(Vector3(0, 7, -44), Color(1.0, 0.95, 0.7))
	make_floating_label("The Summit", Vector3(0, 4, -36), Color(1, 0.97, 0.8))

	spawn_player(Vector3(0, 1, 9))

	make_trigger(Vector3(0, 1.5, -33), Vector3(10, 4, 2), func(_b):
		GameState.set_flag("reached_summit", true)
		QuestManager.update_quest_progress("climb_hill")
		EventBus.toast("You crest the summit, breathless and kept. Palace lights glow ahead.")
		_advance_after_delay()
	, false)


func _add_steep_zone(pos: Vector3, size: Vector3) -> void:
	var z := MudZone.new()
	add_child(z)
	z.setup(size, false, Color(0.5, 0.45, 0.38, 0.45))  # rocky, not muddy
	z.position = pos
	z.movement_multiplier = 0.6
	z.effects_per_tick = {"weariness": 1, "perseverance": 1}


func _build_rest_arbor(pos: Vector3) -> void:
	make_decor(Vector3(3, 0.3, 3), Color(0.4, 0.5, 0.35), pos + Vector3(0, 0.15, 0))
	make_floating_label("Rest Arbor", pos + Vector3(0, 1.6, 0), Color(0.8, 0.85, 0.7))
	var arbor := Area3D.new()
	arbor.collision_layer = 0
	arbor.collision_mask = 1
	arbor.monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 3)
	col.shape = box
	arbor.add_child(col)
	arbor.position = pos + Vector3(0, 1, 0)
	arbor.body_entered.connect(_on_arbor_enter)
	arbor.body_exited.connect(_on_arbor_exit)
	add_child(arbor)


func _on_arbor_enter(body: Node) -> void:
	if body is PlayerController:
		_arbor_player = body
		_arbor_time = 0.0
		_arbor_warned = false


func _on_arbor_exit(body: Node) -> void:
	if body == _arbor_player:
		_arbor_player = null


func _process(delta: float) -> void:
	if _arbor_player == null:
		return
	_arbor_time += delta
	if _arbor_time > 6.0 and not _arbor_warned:
		_arbor_warned = true
		EventBus.toast("Rest begins turning into forgetfulness. Rise before comfort masters you.")
	if _arbor_time > 12.0:
		_arbor_time = 0.0
		SpiritualStateManager.apply_effects({"weariness": 10, "watchfulness": -8})
		GameState.set_flag("drowsed_on_hill", true)
		EventBus.toast("You drowse in the arbor, and watchfulness leaks away for a while.")
