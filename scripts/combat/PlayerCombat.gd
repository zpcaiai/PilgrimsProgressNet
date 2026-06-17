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
var prayer_cooldown: float = 0.0
const PRAYER_CD := 6.0

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
		var regen := 4.0 + SpiritualStateManager.hope * 0.05 + SpiritualStateManager.faith * 0.05
		resolve = min(max_resolve, resolve + regen * delta)
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
	_regen_block = 2.0
	if resolve <= 0.0:
		resolve = 0.0
		_stagger()
	emit_signal("stats_changed")


func _stagger() -> void:
	EventBus.toast("Your resolve breaks for a moment, but collapse is not the end.")
	# Despair surges; if it reaches 100 the collapse/repentance flow fires.
	SpiritualStateManager.modify_state("despair", 20)
	resolve = max_resolve * 0.4


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
		EventBus.toast("You strike at the shadow, but truth must finish the work.")


func dodge() -> void:
	if _player and _player.has_method("teleport"):
		var back := -_player.global_transform.basis.z
		_player.global_position += Vector3(back.x, 0, back.z).normalized() * 2.0
	EventBus.toast("You step aside and refuse panic's command.")


func faith_guard() -> void:
	guarding = true
	EventBus.toast("You stand firm beneath the promise.")


func use_promise() -> void:
	if promise_charge <= 0:
		EventBus.toast("No promise is ready on your lips. Stand firm, and remember.")
		return
	promise_charge -= 1
	var e := _nearest_enemy(8.0)
	if e:
		e.receive_counter("promise", 30.0)
		match e.enemy_type:
			"shame": SpiritualStateManager.apply_effects({"shame": -20, "faith": 5})
			"despair": SpiritualStateManager.apply_effects({"despair": -25, "hope": 5})
			"fear": SpiritualStateManager.apply_effects({"fear": -20, "faith": 5})
			_: SpiritualStateManager.apply_effects({"deception": -20, "discernment": 5})
	EventBus.toast("You answer the lie with a promise stronger than shame.")
	emit_signal("stats_changed")


func pray() -> void:
	if prayer_cooldown > 0.0:
		EventBus.toast("Your breath is not ready for another prayer yet.")
		return
	prayer_cooldown = PRAYER_CD
	SpiritualStateManager.apply_effects({"fear": -10, "despair": -10, "hope": 5})
	_prayer_flash()
	# Push nearby enemies back and weaken them slightly.
	for e in get_tree().get_nodes_in_group("enemy"):
		var foe := e as SymbolicEnemy
		if foe != null and _player:
			var away: Vector3 = foe.global_position - _player.global_position
			away.y = 0
			if away.length() < 6.0:
				foe.global_position += away.normalized() * 2.5
				foe.receive_counter("prayer", 6.0)
	EventBus.toast("You pray, and light opens where fear had crowded close.")
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
