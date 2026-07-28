extends GlbChapter
class_name CelestialCity
## Chapter 16. Journey's end. A shining road climbs to the gate of the City.
## Walk up, and the pilgrimage is complete.

var _done: bool = false


func _build_procedural() -> void:
	setup_environment(
		Color(0.6, 0.78, 1.0),
		Color(1.0, 0.95, 0.78),
		1.3
	)
	make_ground(Vector2(30, 60), Color(0.55, 0.6, 0.5))

	# A golden road rising to the gate.
	for i in range(6):
		var z := 0.0 - i * 5.0
		make_decor(Vector3(6, 0.1, 5), Color(1.0, 0.92, 0.65), Vector3(0, 0.06, z), 0.6)

	# The gate and its great light.
	make_block(Vector3(2, 9, 2), Color(0.95, 0.9, 0.7), Vector3(-4, 4.5, -30), 0.4)
	make_block(Vector3(2, 9, 2), Color(0.95, 0.9, 0.7), Vector3(4, 4.5, -30), 0.4)
	make_block(Vector3(10, 2, 1), Color(1.0, 0.95, 0.75), Vector3(0, 9, -30), 0.6)
	var gate_light := OmniLight3D.new()
	gate_light.position = Vector3(0, 6, -32)
	gate_light.light_color = Color(1.0, 0.97, 0.8)
	gate_light.light_energy = 8.0
	gate_light.omni_range = 40.0
	add_child(gate_light)

	make_floating_label("天城 The Celestial City", Vector3(0, 11, -30), Color(1.0, 0.97, 0.82))

	# Those who walked with you, waiting at the gate to welcome you in.
	make_npc("Evangelist", Vector3(-3, 0, -27), Color(0.85, 0.82, 0.7))
	make_npc("Shepherd", Vector3(3, 0, -27), Color(0.7, 0.78, 0.6))
	if GameState.has_companion("hopeful"):
		make_npc("Hopeful", Vector3(0, 0, -25), Color(0.55, 0.8, 0.7))

	spawn_player(Vector3(0, 1, 14))

	# The gate itself: two real leaves that OPEN. The Wicket Gate (chapter 4) has
	# had an opening animation since the world rebuild; the Celestial Gate — the
	# last door in the story — had only a light burst.
	_build_gate()

	# The mirror inside the gate. You reach it after the welcome, and what you
	# see is your own face, named by what actually happened to you on the road.
	_build_mirror()

	make_trigger(Vector3(0, 1.5, -27), Vector3(10, 5, 2), func(_b): _arrive(), true)
	# The bespoke City spectacle (CelestialCityArt) is applied centrally by
	# ChapterBase._apply_world_rebuild() via ChapterArt, like every chapter.


func _arrive() -> void:
	if _done:
		return
	_done = true
	EventBus.lock_player("celestial_arrival")
	_open_gate()
	# Frame the opening from the chapter's own authored approach marker, if the
	# GLB provides one.
	ChapterCamera.shot("ThroneApproach", 4.0, true)
	make_light_burst(Vector3(0, 2, -28), Color(1.0, 0.97, 0.82), 90)
	GameState.set_flag("entered_city", true)
	QuestManager.update_quest_progress("enter_celestial_city")
	ChapterManager.finalize_journey()
	EventBus.toast("城门打开，曾与你同行的人转身欢迎你回家。")
	await get_tree().create_timer(2.6).timeout
	if GameState.has_flag("interpreter_full"):
		EventBus.toast("讲解者也在其中：“你看过我屋里的每盏灯。如今你站在点燃那些灯的光里。”")
		await get_tree().create_timer(3.0).timeout
	if GameState.has_flag("chapel_pilgrim"):
		EventBus.toast("一位牧人微笑：“你曾跪在无人看见的小堂里。天上记得每一次。欢迎你。”")
		await get_tree().create_timer(3.0).timeout
	EventBus.toast("你不是靠自己的力量抵达，而是被恩典托住：每一步都蒙保守。")
	await get_tree().create_timer(3.0).timeout
	EventBus.toast("重担早已远去。旅程已经完成。进入安息吧。")
	await get_tree().create_timer(2.8).timeout
	EventBus.unlock_player("celestial_arrival")
	# The gate is open and the mirror is reachable; the journey review still
	# waits on the player rather than on a timer.
	EventBus.toast("门内有一面镜子。走过去，看一看。")


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------
var _gate_leaves: Array[Node3D] = []
var _mirror: Interactable = null
var _mirror_seen := false


## Two leaves either side of the opening, closed on arrival.
func _build_gate() -> void:
	_gate_leaves.clear()
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(sx * 3.4, 0.0, -28.0)
		add_child(hinge)
		var leaf := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.4, 8.4, 0.45)
		leaf.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.72, 0.34)
		m.metallic = 0.75
		m.roughness = 0.32
		m.emission_enabled = true
		m.emission = Color(1.0, 0.9, 0.6)
		m.emission_energy_multiplier = 0.22
		leaf.material_override = m
		leaf.position = Vector3(-sx * 1.7, 4.2, 0.0)
		hinge.add_child(leaf)
		_gate_leaves.append(hinge)


## Swing them wide. Slow, because this door has been the destination since the
## first chapter and should not snap.
func _open_gate() -> void:
	for i in range(_gate_leaves.size()):
		var hinge := _gate_leaves[i]
		if not is_instance_valid(hinge):
			continue
		var sign_ := 1.0 if i == 0 else -1.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25 + float(i) * 0.12)
		tw.tween_property(hinge, "rotation:y", sign_ * 1.35, 3.2)
	AudioManager.play_sfx("blessing")


# ---------------------------------------------------------------------------
# The mirror
# ---------------------------------------------------------------------------
## "You did not arrive by your own strength." — said to your own face, and
## specific to your own journey.
func _build_mirror() -> void:
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(2.3, 3.4, 0.25)
	frame.mesh = fb
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.82, 0.70, 0.36)
	fm.metallic = 0.7
	fm.roughness = 0.3
	frame.material_override = fm
	frame.position = Vector3(0, 1.9, -36.0)
	add_child(frame)

	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.9, 3.0)
	glass.mesh = q
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.88, 0.93, 1.0, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.metallic = 0.95
	gm.roughness = 0.06
	gm.emission_enabled = true
	gm.emission = Color(0.85, 0.92, 1.0)
	gm.emission_energy_multiplier = 0.35
	glass.material_override = gm
	glass.position = Vector3(0, 1.95, -35.85)
	add_child(glass)

	make_floating_label("镜 The Glass", Vector3(0, 3.9, -36), Color(0.92, 0.95, 1.0))
	_mirror = make_interactable(Vector3(0, 0, -34.6), "在镜前站住 (Look)",
		func(_p): _look_in_mirror(), null, Color(0.85, 0.92, 1.0), 0.5, 1.8, true)


func _look_in_mirror() -> void:
	if _mirror_seen:
		return
	_mirror_seen = true
	GameState.set_flag("looked_in_the_glass", true)
	EventBus.lock_player("celestial_mirror")
	EventBus.toast("镜子里是你自己的脸。你认得它，也几乎认不出它。")
	await get_tree().create_timer(3.0).timeout
	# What the glass says is assembled from what actually happened to you.
	for line in _mirror_lines():
		EventBus.toast(line)
		await get_tree().create_timer(3.2).timeout
		if not is_inside_tree():
			return
	EventBus.toast("「你不是靠力量走到这里的，是被恩典托住的。每一步都有人扶着。如今，安息吧。」")
	await get_tree().create_timer(3.4).timeout
	EventBus.unlock_player("celestial_mirror")
	GameState.set_flag("journey_review_requested", true)


## Three sentences drawn from this pilgrim's own road.
func _mirror_lines() -> Array[String]:
	var out: Array[String] = []
	if GameState.has_flag("burden_fallen"):
		out.append("「你背进来的那个东西，不在你背上了。你还记得它的重量，那也没关系。」")
	if GameState.has_flag("stood_against_accuser") or GameState.has_flag("defeated_apollyon"):
		out.append("「有人当面告诉你，你值多少。他数错了。」")
	if GameState.has_flag("recalled_promise_in_cell"):
		out.append("「牢门是真的。钥匙也是真的，而且一直在你怀里。」")
	if GameState.has_flag("hopeful_true_friend") or GameState.has_companion("hopeful"):
		out.append("「你不是一个人走完的。这一点，也是恩典。」")
	var tally := TemptationMoment.tally()
	if int(tally.get("yielded", 0)) > 0:
		out.append("「你也让步过。那些地方，你后来还是回到了路上。」")
	elif int(tally.get("resisted", 0)) >= 6:
		out.append("「你站住过很多次。站得住，也不是你自己站的。」")
	if out.is_empty():
		out.append("「你走到了。这就够了。」")
	# Three at most: a mirror should not lecture.
	return out.slice(0, 3)
