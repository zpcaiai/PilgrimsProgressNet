extends Node3D
class_name ChapterBase
## Base class for every chapter. Provides procedural builders so chapters need
## no editor wiring. Subclasses override `_build_chapter()`.

var player: PlayerController = null
var _spawn_position: Vector3 = Vector3(0, 1.0, 0)
var _advancing: bool = false


var companion: Companion = null


func _ready() -> void:
	_build_chapter()
	if player == null:
		spawn_player(_spawn_position)
	# Re-spawn a travelling companion if one has joined the pilgrim.
	if companion == null and GameState.has_companion("hopeful"):
		spawn_companion("Hopeful", Color(0.55, 0.8, 0.7))
	# Optional multiplayer layer: render other pilgrims' async ghosts in this
	# chapter. Fully inert (and skipped) if the net layer isn't installed.
	_attach_ghost_layer()


func _attach_ghost_layer() -> void:
	var net := get_node_or_null("/root/NetConfig")
	if net == null or not net.enabled or player == null:
		return
	var gr_script: Variant = load("res://scripts/level/GhostRenderer.gd")
	if gr_script == null:
		return
	var gr: Node = gr_script.new()
	add_child(gr)
	gr.bind_player(player)


func spawn_companion(display_name: String, color: Color) -> Companion:
	companion = Companion.new()
	companion.setup(display_name, color)
	add_child(companion)
	return companion


## Override in subclasses.
func _build_chapter() -> void:
	pass


# ---------------------------------------------------------------------------
# Environment & lighting
# ---------------------------------------------------------------------------
func setup_environment(sky_top: Color, sky_horizon: Color, ambient_energy: float = 1.0,
		fog_enabled: bool = false, fog_color: Color = Color(0.5, 0.5, 0.55), fog_density: float = 0.02) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = sky_top
	mat.sky_horizon_color = sky_horizon
	mat.ground_bottom_color = sky_horizon.darkened(0.4)
	mat.ground_horizon_color = sky_horizon
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	if fog_enabled:
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = fog_density
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = ambient_energy
	add_child(sun)


func make_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
func make_ground(size: Vector2, color: Color, pos: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size.x, 0.5, size.y)
	mesh.mesh = plane
	mesh.position = Vector3(0, -0.25, 0)
	# Optional per-chapter ground texture (existence-checked; falls back to the
	# flat color when the asset is absent).
	var gmat := make_material(color)
	var gtex := AssetLib.ground(ChapterManager.current_chapter_id)
	if gtex != null:
		gmat.albedo_color = Color(1, 1, 1)
		gmat.albedo_texture = gtex
		gmat.uv1_scale = Vector3(maxf(1.0, size.x / 4.0), maxf(1.0, size.y / 4.0), 1.0)
	mesh.material_override = gmat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 0.5, size.y)
	col.shape = box
	col.position = Vector3(0, -0.25, 0)
	body.add_child(col)

	add_child(body)
	return body


func make_block(size: Vector3, color: Color, pos: Vector3, emission: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = make_material(color, emission)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = size
	col.shape = cshape
	body.add_child(col)
	add_child(body)
	return body


func make_ramp(size: Vector3, color: Color, pos: Vector3, angle_deg: float) -> StaticBody3D:
	# A walkable slope (rotated about X). Keep angle below ~30 so the pilgrim
	# can climb it with the default floor angle.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	body.rotation_degrees = Vector3(angle_deg, 0, 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = make_material(color)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = size
	col.shape = cshape
	body.add_child(col)
	add_child(body)
	return body


func make_decor(size: Vector3, color: Color, pos: Vector3, emission: float = 0.0) -> MeshInstance3D:
	# Non-colliding visual prop.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = make_material(color, emission)
	add_child(mesh)
	return mesh


func make_light_burst(pos: Vector3, color: Color = Color(1.0, 0.95, 0.7), amount: int = 48) -> GPUParticles3D:
	# A one-shot rising shimmer — used for grace/light moments.
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 2.0
	p.one_shot = false
	p.explosiveness = 0.2
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, 0.5, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.2
	mat.color = color
	p.process_material = mat
	var draw := QuadMesh.new()
	draw.size = Vector2(0.25, 0.25)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = color
	dmat.emission_enabled = true
	dmat.emission = color
	dmat.emission_energy_multiplier = 2.0
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Optional soft particle sprite (existence-checked).
	var ptex := AssetLib.particle("mote")
	if ptex != null:
		dmat.albedo_texture = ptex
		dmat.emission_texture = ptex
	draw.material = dmat
	p.draw_pass_1 = draw
	add_child(p)
	return p


func make_floating_label(text: String, pos: Vector3, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.pixel_size = 0.012
	label.outline_size = 8
	add_child(label)
	return label


# ---------------------------------------------------------------------------
# Player
# ---------------------------------------------------------------------------
func spawn_player(pos: Vector3) -> PlayerController:
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.teleport(pos)
	return player


# ---------------------------------------------------------------------------
# NPCs & interactables
# ---------------------------------------------------------------------------
func make_npc(npc_name: String, pos: Vector3, color: Color, dialogue_id: String = "",
		prompt: String = "", on_interact: Callable = Callable()) -> Interactable:
	var area := Interactable.new()
	area.name = npc_name
	area.position = pos
	area.prompt = prompt if prompt != "" else "Talk to " + npc_name
	# Body mesh
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position = Vector3(0, 0.9, 0)
	mesh.material_override = make_material(color)
	area.add_child(mesh)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	head.mesh = sphere
	head.position = Vector3(0, 1.85, 0)
	head.material_override = make_material(color.lightened(0.2))
	area.add_child(head)
	# Floating name
	var label := Label3D.new()
	label.text = npc_name
	label.position = Vector3(0, 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.009
	label.outline_size = 6
	area.add_child(label)
	# Trigger shape
	var col := CollisionShape3D.new()
	var cshape := CapsuleShape3D.new()
	cshape.radius = 0.6
	cshape.height = 1.8
	col.shape = cshape
	col.position = Vector3(0, 0.9, 0)
	area.add_child(col)

	if on_interact.is_valid():
		area.interact_callback = on_interact
	elif dialogue_id != "":
		area.interact_callback = func(_p): DialogueManager.start_dialogue(dialogue_id)
	add_child(area)
	return area


func make_interactable(pos: Vector3, prompt: String, on_interact: Callable,
		mesh: Mesh = null, color: Color = Color(0.8, 0.8, 0.9), emission: float = 0.0,
		radius: float = 1.2, one_shot: bool = false) -> Interactable:
	var area := Interactable.new()
	area.position = pos
	area.prompt = prompt
	area.interact_callback = on_interact
	area.one_shot = one_shot
	var mi := MeshInstance3D.new()
	if mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.8, 0.6)
		mesh = box
	mi.mesh = mesh
	mi.position = Vector3(0, 0.4, 0)
	mi.material_override = make_material(color, emission)
	area.add_child(mi)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	col.shape = sphere
	col.position = Vector3(0, 0.5, 0)
	area.add_child(col)
	add_child(area)
	return area


# ---------------------------------------------------------------------------
# Triggers (detect the player body on layer 1)
# ---------------------------------------------------------------------------
func make_trigger(pos: Vector3, size: Vector3, on_enter: Callable, once: bool = true) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	area.add_child(col)
	var fired := [false]
	area.body_entered.connect(func(body):
		if not (body is PlayerController):
			return
		if once and fired[0]:
			return
		fired[0] = true
		on_enter.call(body)
	)
	add_child(area)
	return area


func make_exit_trigger(pos: Vector3, size: Vector3, condition: Callable = Callable(),
		blocked_message: String = "You are not ready to leave yet.") -> Area3D:
	# Advances to the next chapter when the player enters, if condition passes.
	return make_trigger(pos, size, func(_body):
		if condition.is_valid() and not condition.call():
			EventBus.toast(blocked_message)
			return
		_advance_after_delay()
	, false)


func _advance_after_delay() -> void:
	# Guard against double-advance if an exit trigger fires more than once.
	if _advancing:
		return
	_advancing = true
	# Small delay so toasts/animations settle before the scene swaps.
	await get_tree().create_timer(0.4).timeout
	ChapterManager.go_to_next_chapter()


# ---------------------------------------------------------------------------
# Distant goal light (the Celestial direction) — a recurring motif.
# ---------------------------------------------------------------------------
func make_distant_light(pos: Vector3, color: Color = Color(1.0, 0.95, 0.7)) -> void:
	var omni := OmniLight3D.new()
	omni.position = pos
	omni.light_color = color
	omni.light_energy = 4.0
	omni.omni_range = 30.0
	add_child(omni)
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	glow.mesh = sphere
	glow.position = pos
	glow.material_override = make_material(color, 3.0)
	add_child(glow)


# ---------------------------------------------------------------------------
# Wayside chapel — an optional, secluded shrine. Pausing near it gives a small
# blessing; kneeling inside gives a one-time grace and lights its candle.
# ---------------------------------------------------------------------------
func make_wayside_chapel(pos: Vector3, chapel_id: String, kneel_effects: Dictionary, kneel_text: String) -> void:
	var wall := Color(0.5, 0.48, 0.44)
	make_block(Vector3(3.4, 3.0, 0.4), wall, pos + Vector3(0, 1.5, -1.6))
	make_block(Vector3(0.4, 3.0, 3.2), wall, pos + Vector3(-1.5, 1.5, 0))
	make_block(Vector3(0.4, 3.0, 3.2), wall, pos + Vector3(1.5, 1.5, 0))
	make_decor(Vector3(3.8, 0.5, 3.8), wall.darkened(0.1), pos + Vector3(0, 3.2, 0))
	make_decor(Vector3(0.18, 1.0, 0.18), Color(0.7, 0.6, 0.4), pos + Vector3(0, 4.2, 0))
	make_decor(Vector3(0.7, 0.18, 0.18), Color(0.7, 0.6, 0.4), pos + Vector3(0, 4.35, 0))
	var glow := OmniLight3D.new()
	glow.position = pos + Vector3(0, 1.6, 0)
	glow.light_color = Color(1.0, 0.85, 0.55)
	glow.light_energy = 1.0
	glow.omni_range = 7.0
	add_child(glow)
	var candle := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.2, 0.5, 0.2)
	candle.mesh = cm
	candle.position = pos + Vector3(0, 0.55, -1.0)
	candle.material_override = make_material(Color(0.4, 0.38, 0.3))
	add_child(candle)

	# Pausing near the chapel is itself a small blessing (once).
	var pause := Area3D.new()
	pause.collision_layer = 0
	pause.collision_mask = 1
	pause.monitoring = true
	var pcol := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(5, 4, 5)
	pcol.shape = pbox
	pause.add_child(pcol)
	pause.position = pos + Vector3(0, 1, 1.5)
	var pflag := "paused_chapel_" + chapel_id
	pause.body_entered.connect(func(b):
		if b is PlayerController and not GameState.has_flag(pflag):
			GameState.set_flag(pflag, true)
			SpiritualStateManager.apply_effects({"watchfulness": 2})
			EventBus.toast("A small chapel stands off the road. You slow, and breathe.")
	)
	add_child(pause)

	# Kneeling gives a one-time grace and lights the candle.
	make_floating_label("A wayside chapel", pos + Vector3(0, 2.7, 1.5), Color(0.85, 0.82, 0.7))
	make_interactable(pos + Vector3(0, 0, 1.0), "Kneel a moment",
		func(_p):
			if GameState.has_flag("found_chapel_" + chapel_id):
				return
			GameState.set_flag("found_chapel_" + chapel_id, true)
			SpiritualStateManager.apply_effects(kneel_effects)
			GameState.add_inventory_item("chapels_found", 1)
			var lit := make_material(Color(1.0, 0.9, 0.6))
			lit.emission_enabled = true
			lit.emission = Color(1.0, 0.85, 0.5)
			lit.emission_energy_multiplier = 3.0
			if is_instance_valid(candle):
				candle.material_override = lit
			make_light_burst(pos + Vector3(0, 1.0, -1.0), Color(1.0, 0.9, 0.6), 26)
			EventBus.toast(kneel_text)
			AudioManager.play_sfx("chapel_kneel")
			_check_chapel_meta()
		, null, Color(0.7, 0.65, 0.5), 0.6, 1.4, true)


func _check_chapel_meta() -> void:
	if GameState.get_item_count("chapels_found") >= 4 and not GameState.has_flag("chapel_pilgrim"):
		GameState.set_flag("chapel_pilgrim", true)
		EventBus.toast("You have not passed one prayer-place by. This quiet faithfulness will be remembered at the end.")
		AudioManager.play_sfx("blessing")
