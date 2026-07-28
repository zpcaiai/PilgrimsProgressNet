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


# ---------------------------------------------------------------------------
# A bull-headed devil instead of the generic foe body (Rev 9 / Bunyan's
# "Apollyon ... clothed with scales like a fish, wings like a dragon, feet like
# a bear"). Faces +Z; SymbolicEnemy turns `_fig` toward the pilgrim.
func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 2.3
	col.shape = shape
	col.position = Vector3(0, 1.15, 0)
	add_child(col)

	_fig = Node3D.new()
	add_child(_fig)

	var hide := _demon_mat(Color(0.17, 0.07, 0.08), 0.85)
	var hide_dark := _demon_mat(Color(0.10, 0.05, 0.06), 0.9)
	var armor := _demon_mat(Color(0.16, 0.16, 0.19), 0.45, 0.7)
	var horn := _demon_mat(Color(0.83, 0.78, 0.64), 0.6)
	var hoof := _demon_mat(Color(0.07, 0.05, 0.05), 0.6, 0.1)
	var eye := _demon_mat(Color(1.0, 0.25, 0.12), 0.3)
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.28, 0.1)
	eye.emission_energy_multiplier = 3.2

	# legs + cloven hooves
	for sx in [-0.32, 0.32]:
		_box(_fig, Vector3(0.34, 0.95, 0.42), hide, Vector3(sx, 0.72, 0))
		_box(_fig, Vector3(0.36, 0.3, 0.55), hoof, Vector3(sx, 0.15, 0.12))
	# broad hunched torso + scaled chest plate
	_box(_fig, Vector3(1.3, 1.0, 0.74), hide, Vector3(0, 1.45, 0))
	_box(_fig, Vector3(1.02, 0.74, 0.26), armor, Vector3(0, 1.52, 0.42))
	for sx in [-0.72, 0.72]:
		_sphere(_fig, 0.35, armor, Vector3(sx, 1.86, 0))
	# heavy arms + fists
	for sx in [-0.8, 0.8]:
		_box(_fig, Vector3(0.32, 1.15, 0.36), hide_dark, Vector3(sx, 1.22, 0.05))
		_sphere(_fig, 0.22, hide_dark, Vector3(sx, 0.62, 0.12))
	# neck + bull skull (muzzle reaching +Z)
	_box(_fig, Vector3(0.42, 0.32, 0.42), hide_dark, Vector3(0, 2.02, 0.04))
	_box(_fig, Vector3(0.66, 0.58, 0.62), hide, Vector3(0, 2.28, 0.12))
	_box(_fig, Vector3(0.48, 0.42, 0.52), hide, Vector3(0, 2.14, 0.52))
	_box(_fig, Vector3(0.5, 0.16, 0.14), hide_dark, Vector3(0, 1.99, 0.74))
	for sx in [-0.12, 0.12]:
		_sphere(_fig, 0.05, hide_dark, Vector3(sx, 2.05, 0.78))
	# glowing red eyes
	for sx in [-0.18, 0.18]:
		_sphere(_fig, 0.095, eye, Vector3(sx, 2.37, 0.42))
	# ears
	for sx in [-0.44, 0.44]:
		var ear := _cone(_fig, 0.12, 0.32, hide, Vector3(sx, 2.42, 0.02))
		ear.rotation = Vector3(0, 0, (-0.9 if sx > 0.0 else 0.9))
	# great curved horns sweeping up and forward
	for sx in [-1.0, 1.0]:
		var h1 := _cone(_fig, 0.14, 0.55, horn, Vector3(sx * 0.27, 2.55, 0.1))
		h1.rotation = Vector3(0.2, 0, -sx * 0.6)
		var h2 := _cone(_fig, 0.1, 0.5, horn, Vector3(sx * 0.52, 2.9, 0.22))
		h2.rotation = Vector3(0.5, 0, -sx * 0.4)
		var h3 := _cone(_fig, 0.055, 0.4, horn, Vector3(sx * 0.64, 3.18, 0.46))
		h3.rotation = Vector3(0.95, 0, -sx * 0.2)
	# dragon/bat wings behind the shoulders
	for sx in [-1.0, 1.0]:
		var wing := _box(_fig, Vector3(0.09, 2.1, 1.7), hide_dark, Vector3(sx * 1.15, 2.0, -0.55))
		wing.rotation = Vector3(0.2, sx * 0.55, sx * 0.32)

	# a smouldering red glow about him
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.18)
	glow.light_energy = 2.2
	glow.omni_range = 7.0
	glow.position = Vector3(0, 1.7, 0.4)
	_fig.add_child(glow)

	var label := Label3D.new()
	label.text = "亚玻伦 / Apollyon"
	label.position = Vector3(0, 3.7, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.5, 0.4)
	label.pixel_size = 0.01
	label.outline_size = 7
	add_child(label)


func _demon_mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.3
	return m


func _box(parent: Node3D, size: Vector3, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _sphere(parent: Node3D, r: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


func _cone(parent: Node3D, r: float, h: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


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


# --------------------------------------------------------------------------
# THREE PHASES THAT ACTUALLY DIFFER
#
# The fight was described as three phases and implemented as one: `_attack()`
# swapped which dictionary of numbers it applied and changed nothing else. Same
# cadence, same behaviour, same counterplay — so a player experienced one attack
# repeated until the bar emptied, while the toast claimed the phase had changed.
#
# Each phase now has its own verb, and each verb has its own answer:
#
#   1 INTIMIDATION  — a bellow: a wide roar that hits hardest if you are close
#                     and facing him. ANSWER: back off / guard. Telegraphed by a
#                     rising rumble so it can be read.
#   2 ACCUSATION    — named charges as AccusationCards drifting at you.
#                     ANSWER: the matching promise (see AccusationCard).
#   3 DESPERATE ASSAULT — a charge along your position with a real dodge window.
#                     ANSWER: dodge, then punish while he is over-committed.
#
# Every phase still applies the data-driven `attack_effects` from
# data/enemies/apollyon.json, so tuning stays in data.

const CHARGE_LIST := ["unworthy", "failure", "secret", "abandoned", "pointless"]
const ROAR_RADIUS := 6.5
const DIVE_SPEED := 15.0
const DIVE_TIME := 0.55

var _charge_bag: Array[String] = []
var _telegraph: float = 0.0
var _diving: bool = false
var _dive_dir: Vector3 = Vector3.ZERO
var _dive_t: float = 0.0
var _recovering: float = 0.0


func _phase_effects() -> Dictionary:
	for p in phases:
		if int(p.get("phase", 0)) == current_phase:
			return p.get("attack_effects", attack_effects)
	return attack_effects


func _attack() -> void:
	match current_phase:
		1:
			_attack_roar()
		2:
			_attack_accusation()
		_:
			_attack_dive()


## PHASE 1 — a bellow. Radial, so distance is the answer; telegraphed so the
## distance can be taken.
func _attack_roar() -> void:
	_telegraph = 0.9
	Juice.shake(0.18)
	EventBus.toast("亚玻伦深吸一口气——退开。")
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_telegraph = 0.0
	var p := _player_node()
	Juice.shake(0.7)
	Juice.flash(Color(0.55, 0.10, 0.10, 0.20), 0.35)
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	if d > ROAR_RADIUS:
		EventBus.toast("吼声从你身边掠过。距离也是一种回答。")
		SpiritualStateManager.apply_effects({"fear": 2})
		return
	# Full force at his feet, tapering to nothing at the edge.
	var falloff := clampf(1.0 - d / ROAR_RADIUS, 0.25, 1.0)
	var eff := _scaled(_phase_effects(), falloff)
	SpiritualStateManager.apply_effects(eff)
	_hit_player(eff)


## PHASE 2 — named accusations you can answer one at a time.
func _attack_accusation() -> void:
	var p := _player_node()
	if p == null:
		return
	if _charge_bag.is_empty():
		_charge_bag = CHARGE_LIST.duplicate()
		_charge_bag.shuffle()
	var charge: String = _charge_bag.pop_back()
	var from := global_position + Vector3(0, 2.4, 0) \
		+ (p.global_position - global_position).normalized() * 1.6
	var card := AccusationCard.make(charge, from, p)
	# Scale the landing cost by the tuned phase effects so data still drives it.
	card.effects_on_land = _phase_effects().duplicate()
	get_parent().add_child(card)
	# A charge that lands weakens you; a charge you answer weakens HIM.
	var on_answer := func(correct: bool):
		receive_counter("promise", 26.0 if correct else 14.0)
	card.answered.connect(on_answer)
	Juice.shake(0.14)


## PHASE 3 — a committed charge with a dodge window and a punish window.
func _attack_dive() -> void:
	var p := _player_node()
	if p == null or _diving:
		return
	_telegraph = 0.5
	EventBus.toast("他俯身冲来——闪开。")
	Juice.shake(0.22)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or p == null or not is_instance_valid(p):
		return
	_telegraph = 0.0
	_dive_dir = (p.global_position - global_position)
	_dive_dir.y = 0.0
	_dive_dir = _dive_dir.normalized()
	_dive_t = DIVE_TIME
	_diving = true


func _physics_process(delta: float) -> void:
	if _recovering > 0.0:
		_recovering -= delta
	if not _diving:
		# Normal pursuit / attack cadence lives in SymbolicEnemy. Overriding
		# _physics_process WITHOUT chaining would have silently disabled his
		# chase and his whole attack timer.
		super._physics_process(delta)
		return
	# --- committed charge --------------------------------------------------
	_dive_t -= delta
	velocity.x = _dive_dir.x * DIVE_SPEED
	velocity.z = _dive_dir.z * DIVE_SPEED
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	var p := _player_node()
	if p != null and global_position.distance_to(p.global_position) < 1.9:
		var eff := _phase_effects()
		SpiritualStateManager.apply_effects(eff)
		_hit_player(eff)
		Juice.shake(0.8)
		Juice.hitstop(0.09)
		_end_dive()
		return
	if _dive_t <= 0.0:
		# Over-committed: a window where counters bite twice as hard.
		_end_dive()
		_recovering = 1.6
		EventBus.toast("他冲空了，重心散了——就是现在。")


func _end_dive() -> void:
	_diving = false
	_dive_t = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


## Counters land harder while he is recovering from a missed charge.
func receive_counter(source_type: String, amount: float) -> void:
	# Punish window: a counter landed while he is recovering from a missed
	# charge is worth double. This is the reward for reading the telegraph.
	if _recovering > 0.0:
		amount *= 2.0
		FloatingNumbers.spawn(global_position + Vector3.UP * 3.0, "破绽 ×2",
			Color(1.0, 0.9, 0.55), 30)
	# The base class handles influence, hit feedback and defeat; we only add the
	# phase bookkeeping on top.
	super.receive_counter(source_type, amount)
	if is_instance_valid(self):
		_update_phase()


func _scaled(effects: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in effects.keys():
		out[key] = int(round(float(effects[key]) * k))
	return out


func _hit_player(effects: Dictionary) -> void:
	var combats := get_tree().get_nodes_in_group("player_combat")
	if combats.size() > 0:
		combats[0].take_hit(effects, enemy_type)


func _player_node() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Node3D


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
		var names := ["", "恐吓 Intimidation", "控告 Accusation", "困兽之斗 Desperate Assault"]
		var how := ["",
			"他要吼——离远些，或站稳。",
			"他要一句句控告你——用应许逐句回应（U）。",
			"他要俯冲——闪开（K），然后趁他重心散时反击。"]
		EventBus.toast("第 %d 阶段：%s。%s" % [
			current_phase, names[mini(current_phase, 3)], how[mini(current_phase, 3)]])
		Juice.shake(0.5)
		Juice.flash(Color(0.6, 0.12, 0.12, 0.22), 0.35)


func on_defeated() -> void:
	if not victory_effects.is_empty():
		SpiritualStateManager.apply_effects(victory_effects)
	GameState.set_flag("defeated_apollyon", true)
	GameState.set_flag("stood_against_accuser", true)
	EventBus.toast("亚玻伦被胜过了。你能站立，是因怜悯托住你。")
	Juice.shake(1.0)
	Juice.hitstop(0.15)
	Juice.flash(Color(1.0, 0.95, 0.7, 0.4), 0.8)
	boss_defeated.emit()
	queue_free()
