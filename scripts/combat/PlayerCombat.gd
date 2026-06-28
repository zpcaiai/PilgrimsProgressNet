extends Node
class_name PlayerCombat
## Symbolic combat actions for the pilgrim. Not damage-trading: the pilgrim
## stands firm (faith_guard), prays for space, and answers lies with promises.
## Attach as a child of the player. Keys: J light, K dodge, L guard, U promise,
## P pray.

signal stats_changed()

var resolve: float = 100.0
var max_resolve: float = 100.0
var promise_charge: int = 1
const MAX_PROMISE := 3
var prayer_cooldown: float = 0.0
const PRAYER_CD := 6.0
# Promises also slowly return to mind on their own, so a pilgrim who forgets to
# guard is never permanently stranded at zero with no way to answer.
var _promise_regen: float = 0.0
const PROMISE_REGEN_CD := 5.0

var guarding: bool = false
var _player: Node3D = null
var _regen_block: float = 0.0


func _ready() -> void:
	add_to_group("player_combat")
	_player = get_parent() as Node3D


func _process(delta: float) -> void:
	if prayer_cooldown > 0.0:
		prayer_cooldown -= delta
	# Resolve slowly recovers when not recently hit; hope/faith help.
	if _regen_block > 0.0:
		_regen_block -= delta
	else:
		var regen := 7.0 + SpiritualStateManager.hope * 0.06 + SpiritualStateManager.faith * 0.06
		resolve = min(max_resolve, resolve + regen * delta)
	# Slowly recall a promise even without a parry (capped), so the answer is
	# always within reach.
	if promise_charge < MAX_PROMISE:
		_promise_regen += delta
		if _promise_regen >= PROMISE_REGEN_CD:
			_promise_regen = 0.0
			promise_charge += 1
	else:
		_promise_regen = 0.0
	emit_signal("stats_changed")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		# Track guard release.
		if event is InputEventKey and not event.pressed and event.keycode == KEY_L:
			guarding = false
		return
	match event.keycode:
		KEY_J: light_attack()
		KEY_K: dodge()
		KEY_L: faith_guard()
		KEY_U: use_promise()
		KEY_P: pray()


# --- Incoming ---
func take_hit(effects: Dictionary, _source_type: String) -> void:
	var magnitude := 0.0
	for k in effects.keys():
		if SpiritualStateManager.NEGATIVE_STATES.has(k):
			magnitude += float(effects[k])
	if guarding:
		var guard_strength := SpiritualStateManager.faith + SpiritualStateManager.perseverance
		magnitude *= clampf(1.0 - guard_strength * 0.005, 0.2, 1.0)
		# A firm stand turns accusation into conviction of truth.
		promise_charge = min(3, promise_charge + 1)
	if GameState.is_child_mode():
		magnitude *= 0.5
	resolve -= magnitude
	_regen_block = 1.2
	if magnitude > 0.0:
		Juice.shake(clampf(magnitude * 0.03, 0.12, 0.6))
		Juice.flash(Color(0.92, 0.18, 0.18, clampf(magnitude * 0.010, 0.05, 0.26)), 0.28)
	if resolve <= 0.0:
		resolve = 0.0
		_stagger()
	emit_signal("stats_changed")


func _stagger() -> void:
	EventBus.toast("你的定力暂时破碎，但跌倒不是终点。")
	# Despair surges; if it reaches 100 the collapse/repentance flow fires.
	SpiritualStateManager.modify_state("despair", 10)
	resolve = max_resolve * 0.5
	Juice.shake(0.9)
	Juice.hitstop(0.12)
	Juice.flash(Color(0.55, 0.1, 0.5, 0.35), 0.5)


# --- Actions ---
func _nearest_enemy(max_dist: float) -> SymbolicEnemy:
	var best: SymbolicEnemy = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is SymbolicEnemy and _player != null:
			var d := _player.global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func light_attack() -> void:
	var e := _nearest_enemy(3.0)
	if e:
		e.receive_counter("light_attack", 12.0)
		Juice.shake(0.18)
		EventBus.toast("你按住真理继续站稳。键盘按 U 使用应许；移动版点「应许」回应。")


func dodge() -> void:
	if _player and _player.has_method("teleport"):
		var back := -_player.global_transform.basis.z
		_player.global_position += Vector3(back.x, 0, back.z).normalized() * 2.0
	EventBus.toast("你侧身避开，不让慌乱发号施令。")


func faith_guard() -> void:
	guarding = true
	EventBus.toast("你在应许下站稳。")


func use_promise() -> void:
	if promise_charge <= 0:
		EventBus.toast("此刻还没有想起可回应的应许。先站稳、祷告或回想经文。")
		return
	promise_charge -= 1
	var e := _nearest_enemy(8.0)
	var trial_type := "deception"
	if e:
		trial_type = e.enemy_type
		e.receive_counter("promise", 30.0)
		Juice.shake(0.45)
		Juice.hitstop(0.07)
		Juice.flash(Color(1.0, 0.95, 0.72, 0.18), 0.3)
		match e.enemy_type:
			"shame": SpiritualStateManager.apply_effects({"shame": -20, "faith": 5})
			"despair": SpiritualStateManager.apply_effects({"despair": -25, "hope": 5})
			"fear": SpiritualStateManager.apply_effects({"fear": -20, "faith": 5})
			_: SpiritualStateManager.apply_effects({"deception": -20, "discernment": 5})
	var card := ScriptureMemory.use_for_trial(trial_type)
	if card.is_empty():
		EventBus.toast("你用应许回应谎言：真理比控告更有分量。")
	else:
		EventBus.toast("你用经文回应：%s｜%s" % [String(card.get("ref", "")), String(card.get("theme_zh", card.get("theme_en", "")))])
	emit_signal("stats_changed")


func pray() -> void:
	if prayer_cooldown > 0.0:
		EventBus.toast("还需要片刻安静，才能再次祷告。")
		return
	prayer_cooldown = PRAYER_CD
	SpiritualStateManager.apply_effects({"fear": -10, "despair": -10, "hope": 5})
	# Prayer brings a promise to mind — so you always have something to answer with.
	promise_charge = min(MAX_PROMISE, promise_charge + 1)
	_prayer_flash()
	Juice.shake(0.22)
	Juice.flash(Color(1.0, 0.96, 0.72, 0.16), 0.35)
	# Push nearby enemies back and weaken them slightly.
	for e in get_tree().get_nodes_in_group("enemy"):
		var foe := e as SymbolicEnemy
		if foe != null and _player:
			var away: Vector3 = foe.global_position - _player.global_position
			away.y = 0
			if away.length() < 6.0:
				foe.global_position += away.normalized() * 2.5
				foe.receive_counter("prayer", 6.0)
	var remembered := ScriptureMemory.recall_current_chapter()
	EventBus.toast(ScriptureMemory.recall_line(remembered))
	if not remembered.is_empty():
		var chapter_id := GameState.current_chapter_id if GameState.current_chapter_id != "" else ChapterManager.current_chapter_id
		var guard := "prayer_reflection_" + chapter_id
		if chapter_id != "" and not GameState.has_flag(guard):
			GameState.set_flag(guard, true)
			EventBus.learning_moment_requested.emit({
				"title": "祷告回想：" + String(remembered.get("ref", "")),
				"body": ScriptureMemory.learning_body(remembered)
			})
	emit_signal("stats_changed")


func _prayer_flash() -> void:
	if _player == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.7)
	light.light_energy = 5.0
	light.omni_range = 8.0
	light.position = Vector3(0, 1.0, 0)
	_player.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 1.2)
	tw.tween_callback(light.queue_free)
