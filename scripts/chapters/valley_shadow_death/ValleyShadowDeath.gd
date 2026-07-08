extends GlbChapter
class_name ValleyShadowDeath
## Chapter 10. A pitch-dark, narrow path. Your lantern of faith lights only a
## small circle; fear shrinks it, faith and the lanterns of the Word restore it.
## Whispers from the dark raise fear. Pools of deeper dark press on (snuff) the
## lamp until you move clear. Keep to the path and reach the dawn.

var _lantern: PlayerLight = null
var _shadow_player: PlayerController = null
var _shadow_accum: float = 0.0
var _vignette: DarkVignette = null
var _shadow_discernment_installed: bool = false


func _after_glb_built() -> void:
	_install_shadow_discernment()


func _build_procedural() -> void:
	setup_environment(
		Color(0.02, 0.02, 0.05),
		Color(0.06, 0.05, 0.1),
		0.12,
		true, Color(0.05, 0.05, 0.1), 0.06
	)
	make_ground(Vector2(8, 90), Color(0.12, 0.12, 0.15))
	# Cliff walls hemming the narrow way.
	make_block(Vector3(1, 8, 90), Color(0.08, 0.08, 0.1), Vector3(-4.5, 4, -20))
	make_block(Vector3(1, 8, 90), Color(0.08, 0.08, 0.1), Vector3(4.5, 4, -20))

	make_wayside_chapel(Vector3(2.4, 0, -37), "shadow", {"faith": 8, "fear": -12, "hope": 4}, "崖缝里有一座点亮的小堂。黑暗不能进入这里；你的灯重新记起光。")

	spawn_player(Vector3(0, 1, 12))
	var lantern := PlayerLight.new()
	player.add_child(lantern)
	_lantern = lantern
	_install_shadow_discernment()

	# Combat is optional here: two weak fear-shades haunt the path. Stand firm
	# (L), pray (P), or simply press on past them to the dawn.
	var pc := PlayerCombat.new()
	player.add_child(pc)
	if SpiritualStateManager.has_promise_key:
		pc.promise_charge = 2
	add_child(CombatHUD.new())
	_spawn_fear_shade(Vector3(1.5, 1, -4))
	_spawn_fear_shade(Vector3(-1.5, 1, -22))

	# Lanterns of the Word — restore your light.
	_place_lantern(Vector3(-2.5, 0, -6), lantern)
	_place_lantern(Vector3(2.5, 0, -20), lantern)
	_place_lantern(Vector3(-2.5, 0, -32), lantern)

	# Pools of deeper dark that snuff the lamp while you linger in them.
	_shadow(Vector3(0, 1, -16))
	_shadow(Vector3(0, 1, -30))

	# The dawn ahead.
	make_distant_light(Vector3(0, 5, -48), Color(1.0, 0.9, 0.7))
	make_floating_label("朝向尚未看见的黎明", Vector3(0, 3, -40), Color(0.8, 0.8, 0.7))

	# Closing-dark vignette (reusable node): edges drown as the lamp is snuffed.
	_vignette = DarkVignette.new()
	add_child(_vignette)

	var _cb1 := func(_b):
		GameState.set_flag("crossed_shadow", true)
		QuestManager.update_quest_progress("cross_shadow")
		EventBus.toast("道路渐宽，灰色晨光证明黑暗并非主宰。")
		_advance_after_delay()
	make_trigger(Vector3(0, 1.5, -44), Vector3(8, 4, 2), _cb1, false)


func _install_shadow_discernment() -> void:
	if _shadow_discernment_installed:
		return
	if not is_instance_valid(player):
		return
	_shadow_discernment_installed = true
	if _lantern == null:
		var lantern := PlayerLight.new()
		player.add_child(lantern)
		_lantern = lantern
	if EventBus.has_signal("choice_selected") and not EventBus.choice_selected.is_connected(_on_shadow_choice):
		EventBus.choice_selected.connect(_on_shadow_choice)
	if EventBus.has_signal("input_pray") and not EventBus.input_pray.is_connected(_on_shadow_pray):
		EventBus.input_pray.connect(_on_shadow_pray)
	make_floating_label("死荫谷：分辨声音，不跟随黑暗", Vector3(0, 2.7, 6), Color(0.82, 0.86, 1.0))
	_discernment_whisper(Vector3(0, 1.5, 2), "w1")
	_discernment_whisper(Vector3(0, 1.5, -7), "w2")
	_discernment_whisper(Vector3(0, 1.5, -14), "w3")
	make_floating_label("枯骨桥 Bone Bridge", Vector3(0, 2.2, -23), Color(0.75, 0.72, 0.68))
	_discernment_whisper(Vector3(0, 1.5, -23), "w4")
	_discernment_whisper(Vector3(0, 1.5, -29), "w5")
	_discernment_whisper(Vector3(2.6, 1.5, -35), "w6")
	_edge_danger(Vector3(-3.35, 1.5, -19), "左边深沟把恐惧说成智慧。回到窄路中心。")
	_edge_danger(Vector3(3.35, 1.5, -27), "右边泥坑把绝望说成诚实。回到窄路中心。")


func _shadow(pos: Vector3) -> void:
	make_decor(Vector3(7, 0.08, 6), Color(0.0, 0.0, 0.02), pos + Vector3(0, -0.45, 0))
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7, 4, 6)
	col.shape = box
	area.add_child(col)
	area.position = pos
	area.body_entered.connect(func(b):
		if b is PlayerController:
			_shadow_player = b
			EventBus.toast("黑暗更浓，压向你的灯。继续走。")
	)
	area.body_exited.connect(func(b):
		if b == _shadow_player:
			_shadow_player = null
	)
	add_child(area)


func _process(delta: float) -> void:
	if _lantern == null:
		return
	if _shadow_player != null:
		_lantern.apply_snuff(delta * 3.0)
		_shadow_accum += delta
		if _shadow_accum >= 2.0:
			_shadow_accum = 0.0
			SpiritualStateManager.apply_effects({"fear": 4})
	# Edge-darkening rises with how snuffed the lamp is; the node eases it.
	if is_instance_valid(_vignette):
		_vignette.set_intensity(_lantern.snuff / 6.0)

func _spawn_fear_shade(pos: Vector3) -> void:
	var e := SymbolicEnemy.new()
	e.load_from_data("fear_shade")
	e.influence = 32.0
	e.max_influence = 32.0
	e.move_speed = 2.2
	add_child(e)
	e.global_position = pos


func _whisper(pos: Vector3, text: String) -> void:
	var _cb2 := func(_b):
		SpiritualStateManager.apply_effects({"fear": 12})
		EventBus.toast(text)
	make_trigger(pos, Vector3(8, 4, 2), _cb2, true)


func _discernment_whisper(pos: Vector3, node_id: String) -> void:
	var _cb := func(_b):
		SpiritualStateManager.apply_effects({"fear": 3})
		DialogueManager.start_dialogue("shadow_whisper_discernment", node_id)
	make_trigger(pos, Vector3(6, 4, 2), _cb, true)


func _edge_danger(pos: Vector3, line: String) -> void:
	var _cb := func(body):
		SpiritualStateManager.apply_effects({"fear": 8, "doubt": 4})
		EventBus.toast(line)
		if body is PlayerController:
			body.teleport(Vector3(0, 1, body.global_position.z + 1.2))
	make_trigger(pos, Vector3(1.8, 4, 26), _cb, false)


func _on_shadow_choice(choice_id: String) -> void:
	if String(ChapterManager.current_chapter_id) != "valley_shadow_death":
		return
	if choice_id.begins_with("promise_") or choice_id.begins_with("discern_"):
		if is_instance_valid(_lantern):
			_lantern.add_boost(3.5)
		make_light_burst(player.global_position + Vector3(0, 1.0, -1.2), Color(0.88, 0.9, 1.0), 20)
		EventBus.toast("你分辨出声音，道路短暂显明。")
	elif choice_id.begins_with("wrong_"):
		if is_instance_valid(_lantern):
			_lantern.apply_snuff(2.0)
		EventBus.toast("你误认了声音，黑暗更近了一些。停下祷告，重新辨认。")


func _on_shadow_pray() -> void:
	if String(ChapterManager.current_chapter_id) != "valley_shadow_death":
		return
	if is_instance_valid(_lantern):
		_lantern.add_boost(4.5)
	make_light_burst(player.global_position + Vector3(0, 1.0, -1.0), Color(1.0, 0.95, 0.65), 18)


func _place_lantern(pos: Vector3, lantern: PlayerLight) -> void:
	var _cb3 := func(_p):
		lantern.add_boost(4.0)
		SpiritualStateManager.apply_effects({"fear": -10, "faith": 5})
		EventBus.toast("话语稳住灯光，下一步显出来。")
		AudioManager.play_sfx("lantern_word")
	make_interactable(pos, "读灯中的话语 (Read)",
		_cb3, null, Color(1.0, 0.9, 0.6), 1.5, 1.3, true)
