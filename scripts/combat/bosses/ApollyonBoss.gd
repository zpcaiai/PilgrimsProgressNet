extends SymbolicEnemy
class_name ApollyonBoss
## The destroyer in the Valley of Humiliation. Three phases — intimidation
## (fear), accusation (shame), desperate assault (all). You win not by raw
## damage but by standing firm, praying, and answering with promises until his
## influence is broken.

signal boss_defeated()
signal phase_changed(phase: int)

var phases: Array = []
var current_phase: int = 1
var victory_effects: Dictionary = {}


func _ready() -> void:
	load_from_data("apollyon")
	super._ready()
	scale = Vector3(1.6, 1.6, 1.6)


func _apply_data(d: Dictionary) -> void:
	super._apply_data(d)
	phases = d.get("phases", [])
	victory_effects = d.get("victory_effects", {})
	# Child mode halves the boss's influence (in SymbolicEnemy); halve the phase
	# thresholds too so all three phases still trigger in order.
	if GameState.is_child_mode():
		for p in phases:
			if p.has("threshold"):
				p["threshold"] = float(p["threshold"]) * 0.5


func _attack() -> void:
	var effects := attack_effects
	for p in phases:
		if int(p.get("phase", 0)) == current_phase:
			effects = p.get("attack_effects", attack_effects)
			break
	SpiritualStateManager.apply_effects(effects)
	var combats := get_tree().get_nodes_in_group("player_combat")
	if combats.size() > 0:
		combats[0].take_hit(effects, enemy_type)


func receive_counter(source_type: String, amount: float) -> void:
	influence -= amount * get_weakness_multiplier(source_type)
	_update_phase()
	if influence <= 0.0:
		on_defeated()


func _update_phase() -> void:
	var new_phase := current_phase
	for p in phases:
		# phases are ordered; threshold is the influence at which this phase ends
		if influence <= float(p.get("threshold", 0)) and int(p.get("phase", 0)) >= current_phase:
			new_phase = int(p.get("phase", 0)) + 1
	new_phase = clampi(new_phase, 1, 3)
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)
		var names := ["", "Intimidation", "Accusation", "Desperate Assault"]
		EventBus.toast("Apollyon presses harder — Phase %d: %s" % [current_phase, names[min(current_phase, 3)]])
		Juice.shake(0.5)
		Juice.flash(Color(0.6, 0.12, 0.12, 0.22), 0.35)


func on_defeated() -> void:
	if not victory_effects.is_empty():
		SpiritualStateManager.apply_effects(victory_effects)
	GameState.set_flag("defeated_apollyon", true)
	GameState.set_flag("stood_against_accuser", true)
	EventBus.toast("Apollyon is overcome. You stood because mercy held you.")
	Juice.shake(1.0)
	Juice.hitstop(0.15)
	Juice.flash(Color(1.0, 0.95, 0.7, 0.4), 0.8)
	boss_defeated.emit()
	queue_free()
