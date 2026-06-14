extends Interactable
class_name PromiseStone
## An interactable stone bearing a short paraphrased line of hope. Single use:
## reading it relieves despair and raises a positive state, then dims.

var line: String = "The way is not lost."
var effects: Dictionary = {"hope": 8, "despair": -12}
var flag: String = ""
var _glow_mesh: MeshInstance3D
var _read: bool = false
var _pulse: float = 0.0


func setup(stone_line: String, stone_effects: Dictionary, set_flag: String = "") -> void:
	line = stone_line
	effects = stone_effects
	flag = set_flag
	one_shot = true
	prompt = "Read the promise stone"
	# Visual
	_glow_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.9, 0.3)
	_glow_mesh.mesh = bm
	_glow_mesh.position = Vector3(0, 0.45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.92, 0.6)
	mat.emission_energy_multiplier = 1.6
	_glow_mesh.material_override = mat
	add_child(_glow_mesh)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.4
	col.shape = shape
	col.position = Vector3(0, 0.5, 0)
	add_child(col)
	interact_callback = _on_read


func _process(delta: float) -> void:
	if _read or not is_instance_valid(_glow_mesh):
		return
	_pulse += delta * 2.0
	var mat := _glow_mesh.material_override as StandardMaterial3D
	if mat:
		mat.emission_energy_multiplier = 1.2 + sin(_pulse) * 0.6


func _on_read(_player: Node) -> void:
	_read = true
	AudioManager.play_sfx("promise")
	SpiritualStateManager.apply_effects(effects)
	if flag != "":
		GameState.set_flag(flag, true)
	EventBus.toast(line)
	# Dim the stone now that it has been read.
	if is_instance_valid(_glow_mesh):
		var mat := _glow_mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.2
			mat.albedo_color = Color(0.4, 0.4, 0.4)
	EventBus.interaction_unavailable.emit()
