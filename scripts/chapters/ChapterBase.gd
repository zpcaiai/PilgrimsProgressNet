extends Node3D
class_name ChapterBase
## Base class for every chapter. Provides procedural builders so chapters need
## no editor wiring. Subclasses override `_build_chapter()`.

var player: PlayerController = null
var _spawn_position: Vector3 = Vector3(0, 1.0, 0)
var _advancing: bool = false


var companion: Companion = null

# Dominant colours sampled from this chapter's painting (top/sky, mid/horizon,
# bottom/ground). Used to harmonise the 3D world's materials with the art.
var _pal_top: Color = Color(0.5, 0.5, 0.5)
var _pal_mid: Color = Color(0.5, 0.5, 0.5)
var _pal_bot: Color = Color(0.3, 0.3, 0.3)
var _pal_ok: bool = false


# --- TEMP DEBUG: build trace (remove after diagnosis) ---
static var _trace: PackedStringArray = []
func _dbg(msg: String) -> void:
	if not OS.has_feature("editor"):
		return  # temporary build-trace: editor runs only, never in exported builds
	_trace.append(msg)
	var f := FileAccess.open("res://_pp_trace.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_trace))
		f.close()
	print("[PPTRACE] ", msg)


func _ready() -> void:
	_dbg("=== ready_start " + ChapterManager.current_chapter_id + " ===")
	# Ease every chapter in from black so transitions between scenes of very
	# different brightness never hard-cut.
	_fade_in()
	# Spawn the player (and its camera) FIRST, so a runtime error in any later
	# build/dressing step can never leave the scene cameraless (black). The
	# chapter's own spawn_player(...) call later just repositions this one.
	if player == null:
		spawn_player(_spawn_position)
	# Oil-painting layers (palette harmonising + painting-as-sky) only run in the
	# stylised look. Realistic mode uses a clean procedural (or photo) sky.
	if not RenderConfig.is_realistic():
		_sample_palette()
	_dbg("build_start")
	_build_chapter()
	_dbg("build_end")
	if RenderConfig.is_realistic():
		_attach_realistic_backdrop()
	else:
		_apply_art_palette()
		_attach_backdrop()
	# Reshape pass: bespoke per-chapter lighting rig, atmosphere (fog/glow/
	# tonemap), environmental set-dressing and (stylised only) the painterly
	# post-process — layered on top of the chapter's own gameplay geometry.
	_dbg("rebuild_start")
	_apply_world_rebuild()
	_dbg("rebuild_end")
	if player == null:
		spawn_player(_spawn_position)
	# Re-spawn a travelling companion if one has joined the pilgrim.
	if companion == null and GameState.has_companion("hopeful"):
		spawn_companion("Hopeful", Color(0.55, 0.8, 0.7))
	# Optional multiplayer layer: render other pilgrims' async ghosts in this
	# chapter. Fully inert (and skipped) if the net layer isn't installed.
	_attach_ghost_layer()


func _attach_ghost_layer() -> void:
	# NetConfig is an autoload, so reference it directly (type-safe — avoids the
	# unsafe-property-access warning that newer Godot escalates to an error).
	if not NetConfig.enabled or player == null:
		return
	var gr_script: Variant = load("res://scripts/level/GhostRenderer.gd")
	if gr_script == null:
		return
	var gr: Node = gr_script.new()
	add_child(gr)
	if gr.has_method("bind_player"):
		gr.call("bind_player", player)


## Painted backdrop that makes the 3D world match the chapter's 2D art. Uses
## AssetLib.scene_art (mode-aware: standard art in Devout mode, the storybook
## "_child" art in Children's mode). Large unshaded panels sit far out on every
## side so the scene reads like the painting from any viewing angle.
func _attach_backdrop() -> void:
	var art := AssetLib.scene_art(ChapterManager.current_chapter_id)
	if art == null:
		return
	# Wrap the whole sky in the chapter painting so the 3D world sits inside the
	# scene from every angle (mode-aware via scene_art). Replaces the procedural
	# sky created in setup_environment(); ambient light is then drawn from it too.
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env == null:
				continue
			var sky := Sky.new()
			var pano := PanoramaSkyMaterial.new()
			pano.panorama = art
			sky.sky_material = pano
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			return


## A short fade-in from black on entering each chapter, so transitions between
## scenes of very different brightness (e.g. the bright Cross into the dark
## Interpreter's House, or the night Valley into bright Vanity Fair) ease through
## black instead of cutting hard. Sits above all UI (layer 200).
func _fade_in() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 200
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(rect, "color:a", 0.0, 0.7)
	tw.tween_callback(cl.queue_free)


## Realistic mode: if a realistic environment photo exists for this chapter, use
## it as the sky/backdrop. Otherwise leave the clean procedural sky that
## setup_environment created (already tuned to the chapter's natural sky colours).
func _attach_realistic_backdrop() -> void:
	var bg := AssetLib.realistic_backdrop(ChapterManager.current_chapter_id)
	if bg == null:
		return
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env == null:
				continue
			var sky := Sky.new()
			var pano := PanoramaSkyMaterial.new()
			pano.panorama = bg
			sky.sky_material = pano
			env.background_mode = Environment.BG_SKY
			env.sky = sky
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			return


## Sample the chapter painting's dominant colours into _pal_* so geometry built
## in _build_chapter() can harmonise with the art. Safe no-op if art is absent.
func _sample_palette() -> void:
	var tex := AssetLib.scene_art(ChapterManager.current_chapter_id)
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	if img.get_width() == 0 or img.get_height() == 0:
		return
	_pal_top = _avg_band(img, 0.0, 0.22)
	_pal_mid = _avg_band(img, 0.40, 0.62)
	_pal_bot = _avg_band(img, 0.80, 1.0)
	_pal_ok = true


## Retint the chapter's sky, horizon, ground, ambient, fog and sun from the
## actual colours of the chapter's painting, so the 3D world's whole palette
## matches the art (mode-aware via scene_art).
func _apply_art_palette() -> void:
	var tex := AssetLib.scene_art(ChapterManager.current_chapter_id)
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	if img.get_width() == 0 or img.get_height() == 0:
		return
	var top := _avg_band(img, 0.0, 0.22)
	var mid := _avg_band(img, 0.40, 0.62)
	var bot := _avg_band(img, 0.80, 1.0)
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			if env != null:
				if env.sky != null:
					var pm := env.sky.sky_material as ProceduralSkyMaterial
					if pm != null:
						pm.sky_top_color = top
						pm.sky_horizon_color = mid
						pm.ground_horizon_color = mid
						pm.ground_bottom_color = bot
				env.ambient_light_color = mid
				if env.fog_enabled:
					env.fog_light_color = mid
		elif c is DirectionalLight3D:
			(c as DirectionalLight3D).light_color = top.lerp(Color(1, 1, 1), 0.5)


## Average colour of a horizontal band of the image (y0..y1 as 0-1 fractions).
func _avg_band(img: Image, y0: float, y1: float) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var ya := int(y0 * h)
	var yb := maxi(ya + 1, int(y1 * h))
	var step_x := maxi(1, int(w / 16.0))
	var step_y := maxi(1, int((yb - ya) / 4.0))
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	var yy := ya
	while yy < yb:
		var xx := 0
		while xx < w:
			var col := img.get_pixel(xx, yy)
			r += col.r
			g += col.g
			b += col.b
			n += 1
			xx += step_x
		yy += step_y
	if n == 0:
		return Color(0.5, 0.5, 0.5)
	return Color(r / n, g / n, b / n)


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
	_dbg("setup_environment")
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
	# Harmonise with the chapter painting, then soften for the storybook child mode.
	if _pal_ok:
		color = color.lerp(_pal_mid, 0.30)
	if GameState.is_child_mode():
		color = color.lerp(Color(1, 1, 1), 0.22)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	# Subdue speculars so lit greybox reads as painted matte form, not plastic.
	m.metallic_specular = 0.3
	# Realistic mode: clamp strong "glowing object" emission to a subtle level so
	# windows/candles still read as lit but nothing glows unnaturally.
	if RenderConfig.is_realistic():
		emission = minf(emission, 0.5)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
func make_ground(size: Vector2, color: Color, pos: Vector3 = Vector3.ZERO) -> StaticBody3D:
	_dbg("make_ground")
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size.x, 0.5, size.y)
	mesh.mesh = plane
	mesh.position = Vector3(0, -0.25, 0)
	# Ground colour pulled toward the painting's ground tone; any texture is then
	# tinted to that hue (brightness-normalised so it doesn't darken).
	var gcol := color
	if _pal_ok:
		gcol = gcol.lerp(_pal_bot, 0.5)
	var gmat := make_material(gcol)
	var gtex := AssetLib.ground(ChapterManager.current_chapter_id)
	if gtex != null:
		var t := gmat.albedo_color
		var mx := maxf(maxf(t.r, t.g), maxf(t.b, 0.001))
		gmat.albedo_color = Color(t.r / mx, t.g / mx, t.b / mx)
		gmat.albedo_texture = gtex
		gmat.uv1_scale = Vector3(maxf(1.0, size.x / 4.0), maxf(1.0, size.y / 4.0), 1.0)
		# PBR companion maps (derived by tools/gen_pbr.py) give the ground real
		# surface relief and varied roughness under the per-chapter lighting.
		var gn := AssetLib.ground_map(ChapterManager.current_chapter_id, "normal")
		if gn != null:
			gmat.normal_enabled = true
			gmat.normal_texture = gn
			gmat.normal_scale = 1.0
		var grm := AssetLib.ground_map(ChapterManager.current_chapter_id, "rough")
		if grm != null:
			gmat.roughness_texture = grm
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


func make_block(size: Vector3, color: Color, pos: Vector3, emission: float = 0.0, surface: String = "") -> StaticBody3D:
	_dbg("make_block " + str(pos))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _surface_or_color(surface, color, emission)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = size
	col.shape = cshape
	body.add_child(col)
	add_child(body)
	return body


func make_ramp(size: Vector3, color: Color, pos: Vector3, angle_deg: float, surface: String = "") -> StaticBody3D:
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
	mesh.material_override = _surface_or_color(surface, color)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = size
	col.shape = cshape
	body.add_child(col)
	add_child(body)
	return body


func make_decor(size: Vector3, color: Color, pos: Vector3, emission: float = 0.0, surface: String = "") -> MeshInstance3D:
	_dbg("make_decor")
	# Non-colliding visual prop.
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _surface_or_color(surface, color, emission)
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
	_dbg("make_floating_label " + text)
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
	_dbg("spawn_player " + str(pos))
	# Idempotent: if a player already exists (e.g. pre-spawned in _ready), just
	# move it to the requested position instead of creating a second one.
	if is_instance_valid(player):
		player.teleport(pos)
		return player
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
	_dbg("make_npc " + npc_name)
	var area := Interactable.new()
	area.name = npc_name
	area.position = pos
	area.prompt = prompt if prompt != "" else "Talk to " + npc_name
	# Visual: a real in-engine 3D body, tinted by the character's palette (with
	# `color` as the fallback garment tint for un-tabled folk). Standing NPCs
	# idle in place (no mover).
	area.add_child(HumanoidFigure.make(npc_name, 2.0, null, true, color))
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
		area.interact_callback = func(_p):
			# Face-on-talk: pilgrim turns to the NPC, the NPC gives a small nod.
			if _p != null and is_instance_valid(_p) and _p.has_method("glance_toward"):
				_p.call("glance_toward", area.global_position)
			var anim := HumanoidAnimator.find_in(area)
			if anim != null:
				anim.nudge(0.07)
			DialogueManager.start_dialogue(dialogue_id)
	add_child(area)
	return area


func make_interactable(pos: Vector3, prompt: String, on_interact: Callable,
		mesh: Mesh = null, color: Color = Color(0.8, 0.8, 0.9), emission: float = 0.0,
		radius: float = 1.2, one_shot: bool = false) -> Interactable:
	_dbg("make_interactable " + prompt)
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
	_dbg("make_trigger")
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
	var _cb1 := func(_body):
		if condition.is_valid() and not condition.call():
			EventBus.toast(blocked_message)
			return
		_advance_after_delay()
	return make_trigger(pos, size, _cb1, false)


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
	_dbg("make_distant_light")
	var omni := OmniLight3D.new()
	omni.position = pos
	omni.light_color = color
	omni.light_energy = 4.0
	omni.omni_range = 30.0
	add_child(omni)
	# Realistic mode: just the light, no floating glowing orb.
	if RenderConfig.is_realistic():
		return
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
	_dbg("make_wayside_chapel " + chapel_id)
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
		if b is PlayerController:
			# Every visit to a cross-bearing chapel lifts faith and hope.
			SpiritualStateManager.apply_effects({"faith": 3, "hope": 3})
			if not GameState.has_flag(pflag):
				GameState.set_flag(pflag, true)
				SpiritualStateManager.apply_effects({"watchfulness": 2})
				EventBus.toast("A small chapel stands off the road. You slow, and breathe.")
	)
	add_child(pause)

	# Kneeling gives a one-time grace and lights the candle.
	make_floating_label("A wayside chapel", pos + Vector3(0, 2.7, 1.5), Color(0.85, 0.82, 0.7))
	var _cb2 := func(_p):
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
	make_interactable(pos + Vector3(0, 0, 1.0), "Kneel a moment",
		_cb2, null, Color(0.7, 0.65, 0.5), 0.6, 1.4, true)


func _check_chapel_meta() -> void:
	if GameState.get_item_count("chapels_found") >= 4 and not GameState.has_flag("chapel_pilgrim"):
		GameState.set_flag("chapel_pilgrim", true)
		EventBus.toast("You have not passed one prayer-place by. This quiet faithfulness will be remembered at the end.")
		AudioManager.play_sfx("blessing")


# ===========================================================================
# World rebuild — painterly / PBR / per-chapter lighting reshape
# ===========================================================================
## Material helper: a named PBR surface (from MaterialKit) when `surface` is
## given, else the flat painterly colour material. Keeps make_block/ramp/decor
## backward compatible while letting dressing request real textured surfaces.
func _surface_or_color(surface: String, color: Color, emission: float = 0.0) -> StandardMaterial3D:
	if surface != "":
		var opts: Dictionary = {}
		if emission > 0.0:
			opts["emission"] = emission
		return MaterialKit.make(surface, color, opts)
	return make_material(color, emission)


## Apply the chapter's art profile after its gameplay geometry is built.
func _apply_world_rebuild() -> void:
	var prof := ChapterArtProfiles.for_chapter(ChapterManager.current_chapter_id)
	_dbg("rb:env")
	_apply_environment(prof)
	_dbg("rb:light")
	_apply_lighting(prof)
	_dbg("rb:dress")
	_apply_dressing(prof.get("dressing", []))
	_dbg("rb:art")
	# Bespoke per-chapter centrepiece (deep-polish layer) on top of the profile.
	ChapterArt.build(self, ChapterManager.current_chapter_id)
	_dbg("rb:postfx")
	# The painterly oil filter is stylised-only (Children's Journey); realistic
	# Devout mode skips it.
	if not RenderConfig.is_realistic():
		_attach_postfx(prof.get("post", {}))


func _find_or_make_env() -> Environment:
	for c in get_children():
		if c is WorldEnvironment:
			var e: Environment = (c as WorldEnvironment).environment
			if e != null:
				return e
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment = env
	add_child(we)
	return env


## Fog (depth + volumetric), glow, tonemap, colour adjustment and SSAO/SSIL,
## tuned per chapter. The chapter painting stays the sky/ambient source; this
## only adds atmosphere and grade on top. Volumetric/SSAO/SSIL apply on Forward+
## and are harmlessly ignored on the gl_compatibility fallback.
func _apply_environment(prof: Dictionary) -> void:
	var env := _find_or_make_env()
	if env == null:
		return
	var amb: Dictionary = prof.get("ambient", {})
	env.ambient_light_energy = float(amb.get("energy", 0.6))
	if env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
		env.ambient_light_color = amb.get("color", Color(0.5, 0.5, 0.55))

	var fog: Dictionary = prof.get("fog", {})
	env.fog_enabled = bool(fog.get("enabled", false))
	if env.fog_enabled:
		env.fog_light_color = fog.get("color", Color(0.6, 0.6, 0.62))
		env.fog_density = float(fog.get("density", 0.012))
		env.fog_aerial_perspective = float(fog.get("aerial", 0.4))
		env.fog_sky_affect = 0.3
	if bool(fog.get("volumetric", false)):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = float(fog.get("vol_density", 0.03))
		env.volumetric_fog_albedo = fog.get("albedo", Color(0.7, 0.72, 0.75))
		env.volumetric_fog_emission = fog.get("emission", Color(0, 0, 0))
		# Realistic mode: no self-lit coloured fog (that "magic glow" look).
		env.volumetric_fog_emission_energy = 0.0 if RenderConfig.is_realistic() else float(fog.get("emission_energy", 0.0))
		env.volumetric_fog_length = 96.0
		env.volumetric_fog_gi_inject = 0.5

	var glow: Dictionary = prof.get("glow", {})
	env.glow_enabled = bool(glow.get("enabled", true))
	if env.glow_enabled:
		var g_intensity := float(glow.get("intensity", 0.8))
		var g_bloom := float(glow.get("bloom", 0.1))
		var g_threshold := float(glow.get("threshold", 0.9))
		# Realistic mode: only true highlights bloom, gently — no painterly halo.
		if RenderConfig.is_realistic():
			g_intensity = minf(g_intensity, 0.4)
			g_bloom = minf(g_bloom, 0.06)
			g_threshold = maxf(g_threshold, 1.0)
		env.glow_intensity = g_intensity
		env.glow_strength = float(glow.get("strength", 1.0))
		env.glow_bloom = g_bloom
		env.glow_hdr_threshold = g_threshold
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	var tm: Dictionary = prof.get("tonemap", {})
	# Realistic mode uses one consistent tonemapper (ACES) across all scenes so
	# the whole journey shares a coordinated colour response; the per-chapter
	# filmic/agx choices are kept for the stylised oil look.
	var tm_mode := String(tm.get("mode", "aces"))
	if RenderConfig.is_realistic():
		tm_mode = "aces"
	env.tonemap_mode = _tonemap_enum(tm_mode)
	env.tonemap_exposure = float(tm.get("exposure", 1.0))
	env.tonemap_white = float(tm.get("white", 1.0))

	var adj: Dictionary = prof.get("adjust", {})
	env.adjustment_enabled = true
	env.adjustment_brightness = float(adj.get("brightness", 1.0))
	env.adjustment_contrast = float(adj.get("contrast", 1.05))
	env.adjustment_saturation = float(adj.get("saturation", 1.08))

	env.ssao_enabled = bool(prof.get("ssao", true))
	if env.ssao_enabled:
		env.ssao_radius = 2.0
		env.ssao_intensity = 1.5
	env.ssil_enabled = bool(prof.get("ssil", false))


func _tonemap_enum(mode: String) -> int:
	match mode:
		"filmic":
			return Environment.TONE_MAPPER_FILMIC
		"agx":
			return Environment.TONE_MAPPER_AGX
		"linear":
			return Environment.TONE_MAPPER_LINEAR
		_:
			return Environment.TONE_MAPPER_ACES


## Bespoke lighting rig: reconfigure the existing sun as a shadow-casting key
## light from the profile, then add a soft shadowless fill from the opposite
## side for painterly form modelling.
func _apply_lighting(prof: Dictionary) -> void:
	var sun_d: Dictionary = prof.get("sun", {})
	var key: DirectionalLight3D = null
	for c in get_children():
		if c is DirectionalLight3D:
			key = c as DirectionalLight3D
			break
	if key == null:
		key = DirectionalLight3D.new()
		add_child(key)
	key.rotation_degrees = sun_d.get("angle", Vector3(-50, -40, 0))
	var kc: Color = sun_d.get("color", Color(1, 1, 1))
	if _pal_ok:
		kc = kc.lerp(_pal_top, 0.15)
	key.light_color = kc
	key.light_energy = float(sun_d.get("energy", 1.1))
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.shadow_blur = 1.2
	key.light_angular_distance = 1.0

	var fill_d: Dictionary = prof.get("fill", {})
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = fill_d.get("angle", Vector3(-25, 150, 0))
	fill.light_color = fill_d.get("color", Color(0.6, 0.7, 0.85))
	fill.light_energy = float(fill_d.get("energy", 0.3))
	fill.shadow_enabled = false
	add_child(fill)


func _apply_dressing(list: Array) -> void:
	for item in list:
		if item is Dictionary:
			_dress_one(item)


## Interpret one dressing entry. Every value is read with a safe default so a
## partially-specified entry still works.
func _dress_one(d: Dictionary) -> void:
	var op := String(d.get("op", ""))
	var tint: Color = d.get("tint", Color(1, 1, 1))
	match op:
		"scatter":
			PropKit.scatter(self, String(d.get("kind", "rock")), d.get("center", Vector3.ZERO), d.get("area", Vector2(10, 10)), int(d.get("count", 6)), tint, int(d.get("seed", 1)))
		"grass":
			PropKit.grass_field(self, d.get("center", Vector3.ZERO), d.get("area", Vector2(40, 40)), int(d.get("count", 400)), tint, int(d.get("seed", 7)))
		"reeds":
			PropKit.reeds(self, d.get("center", Vector3.ZERO), d.get("area", Vector2(8, 16)), int(d.get("count", 40)), tint, int(d.get("seed", 11)))
		"mist":
			PropKit.mist(self, d.get("center", Vector3.ZERO), d.get("area", Vector2(30, 30)), float(d.get("height", 1.4)), d.get("color", Color(0.7, 0.72, 0.75)), int(d.get("seed", 4)))
		"smoke":
			PropKit.smoke(self, d.get("pos", Vector3.ZERO), float(d.get("scale", 1.0)), d.get("color", Color(0.12, 0.11, 0.12)))
		"fire":
			PropKit.fire(self, d.get("pos", Vector3.ZERO), float(d.get("scale", 1.0)), d.get("color", Color(1.0, 0.55, 0.2)))
		"shaft":
			PropKit.light_shaft(self, d.get("pos", Vector3.ZERO), float(d.get("length", 14)), float(d.get("radius", 3)), d.get("color", Color(1.0, 0.93, 0.7)))
		"water":
			PropKit.water_plane(self, d.get("center", Vector3.ZERO), d.get("size", Vector2(20, 20)), tint)
		"ridge":
			PropKit.ridge(self, d.get("center", Vector3.ZERO), float(d.get("length", 60)), float(d.get("height", 20)), tint, String(d.get("surface", "stone")), int(d.get("seed", 9)))
		"cliff":
			PropKit.cliff(self, d.get("pos", Vector3.ZERO), d.get("size", Vector3(6, 8, 10)), tint, String(d.get("surface", "stone")), int(d.get("seed", 3)))
		"boulders":
			PropKit.boulder_cluster(self, d.get("center", Vector3.ZERO), int(d.get("count", 5)), float(d.get("scale", 1.4)), tint, String(d.get("surface", "stone")), int(d.get("seed", 5)))
		"arch":
			PropKit.arch(self, d.get("pos", Vector3.ZERO), float(d.get("width", 3)), float(d.get("height", 4)), tint, String(d.get("surface", "stone")))
		"wall":
			PropKit.wall(self, d.get("pos", Vector3.ZERO), float(d.get("length", 6)), float(d.get("height", 3)), tint, String(d.get("surface", "stone")), int(d.get("axis", 0)))
		"castle_wall":
			PropKit.castle_wall(self, d.get("pos", Vector3.ZERO), float(d.get("length", 8)), float(d.get("height", 4)), tint, int(d.get("axis", 0)), int(d.get("seed", 2)))
		"pillar":
			PropKit.pillar(self, d.get("pos", Vector3.ZERO), float(d.get("height", 4)), tint, String(d.get("surface", "marble")))
		"gate":
			PropKit.gate(self, d.get("pos", Vector3.ZERO), tint, bool(d.get("open", true)))
		"cross":
			PropKit.cross(self, d.get("pos", Vector3.ZERO), float(d.get("height", 4)), tint, bool(d.get("glow", true)))
		"tomb":
			PropKit.tomb(self, d.get("pos", Vector3.ZERO), tint)
		"banner":
			PropKit.banner(self, d.get("pos", Vector3.ZERO), float(d.get("height", 4)), tint)
		"stall":
			PropKit.market_stall(self, d.get("pos", Vector3.ZERO), tint, d.get("cloth", Color(0.7, 0.2, 0.25)))
		"lantern":
			PropKit.lantern_post(self, d.get("pos", Vector3.ZERO), tint, d.get("color", Color(1.0, 0.85, 0.55)))
		"tree":
			PropKit.tree(self, d.get("pos", Vector3.ZERO), float(d.get("height", 4)), tint, int(d.get("seed", 0)))
		"pine":
			PropKit.pine(self, d.get("pos", Vector3.ZERO), float(d.get("height", 5)), tint, int(d.get("seed", 0)))
		"bush":
			PropKit.bush(self, d.get("pos", Vector3.ZERO), float(d.get("radius", 0.8)), tint, int(d.get("seed", 0)))


func _attach_postfx(post: Dictionary) -> void:
	PainterlyPostFX.attach(self, post)
