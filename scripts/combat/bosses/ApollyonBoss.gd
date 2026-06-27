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
		EventBus.toast("亚玻伦压迫更紧：第 %d 阶段（%s）。" % [current_phase, names[min(current_phase, 3)]])
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
