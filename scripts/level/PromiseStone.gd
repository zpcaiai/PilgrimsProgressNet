extends Interactable
class_name PromiseStone
## An interactable stone bearing a short paraphrased line of hope. Single use:
## reading it relieves despair and raises a positive state, then dims.

var line: String = "路并没有失去。"
var effects: Dictionary = {"hope": 8, "despair": -12}
var flag: String = ""
var _glow_mesh: MeshInstance3D
var _read: bool = false
## Key into promise_stone_lines.json for this stone's authored inscription.
var promise_key: String = ""
var _pulse: float = 0.0


func setup(stone_line: String, stone_effects: Dictionary, set_flag: String = "") -> void:
	line = stone_line
	effects = stone_effects
	flag = set_flag
	one_shot = true
	prompt = "读应许石 (Read)"
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
	# `promise_stone_lines.json` holds the authored inscriptions and had NO
	# reader anywhere in the project, so every promise stone showed whatever
	# line its creator happened to pass in. Prefer the authored text — and its
	# Chinese, which only exists in that file — when this stone declares a key.
	EventBus.toast(_inscription())
	# Dim the stone now that it has been read.
	if is_instance_valid(_glow_mesh):
		var mat := _glow_mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.2
			mat.albedo_color = Color(0.4, 0.4, 0.4)
	EventBus.interaction_unavailable.emit()


## The authored inscription for this stone, from data/dialogues/promise_stone_lines.json
## (falls back to whatever `line` the caller supplied).
func _inscription() -> String:
	if promise_key == "" or not DialogueManager.has_dialogue("promise_stone_lines"):
		return line
	var doc := DialogueManager.load_dialogue("promise_stone_lines")
	var lines: Dictionary = doc.get("lines", {})
	if not lines.has(promise_key):
		return line
	var entry: Variant = lines[promise_key]
	if entry is Dictionary:
		var d := entry as Dictionary
		return String(d.get("zh", d.get("en", line)))
	return String(entry)
