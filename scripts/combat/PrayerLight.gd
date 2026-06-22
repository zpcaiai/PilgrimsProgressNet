extends Node3D
class_name PrayerLight
## A short-lived circle of prayer light. Lifts a warm glow that fades over a few
## seconds -- used both in the dark valley (to reveal the path and push back
## whispers) and as the "pray" recovery beat in the Apollyon fight. Self-frees.

const DEFAULT_DURATION := 8.0


static func activate(parent: Node, pos: Vector3, duration: float = DEFAULT_DURATION) -> void:
	if parent == null:
		return
	var pl := PrayerLight.new()
	parent.add_child(pl)
	pl.global_position = pos
	pl._run(duration)


func _run(duration: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.7)
	light.light_energy = 3.0
	light.omni_range = 12.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)

	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	glow.mesh = sphere
	glow.position = Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.6)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = mat
	add_child(glow)

	AudioManager.play_sfx("blessing")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_energy", 0.0, duration)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tw.chain().tween_callback(queue_free)
