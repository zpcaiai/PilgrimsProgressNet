extends CanvasLayer
class_name CinematicPostFX
## Screen-space grade for the DEVOUT (realistic) journey — the mode that until
## now had no post-process at all.
##
## Background: PainterlyPostFX is attached only when RenderConfig.is_realistic()
## is false, i.e. the Children's Journey. The adult mode therefore rendered raw:
## no vignette, no grain, no per-chapter lens character, and — on the
## gl_compatibility web build — no SSAO or volumetric fog either. Sixteen
## chapters ended up separated only by prop colour.
##
## This layer is the counterpart: a single full-screen ColorRect running
## assets/shaders/cinematic.gdshader on CanvasLayer 5 (above the 3D viewport,
## below every HUD layer, which live on 9..22), driven per chapter by the
## `cine` block of ChapterArtProfiles — with a sensible grade derived from the
## chapter's own fog/sun colours when no `cine` block is authored.
##
## Fully inert if the shader is missing, exactly like PainterlyPostFX, so the
## project keeps its "works with any subset of assets" guarantee.

const SHADER_PATH := "res://assets/shaders/cinematic.gdshader"

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _t: float = 0.0


func _ready() -> void:
	layer = 5
	var sh := load(SHADER_PATH) as Shader
	if sh == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	_apply_defaults()


func _process(delta: float) -> void:
	if _mat == null:
		return
	# Animate the grain so it reads as film rather than a static dirt overlay.
	_t += delta
	_mat.set_shader_parameter("time_seed", fmod(_t * 37.0, 1000.0))


func _apply_defaults() -> void:
	configure({
		"strength": 1.0,
		"vignette_amount": 0.30,
		"vignette_softness": 0.62,
		"grain_amount": 0.020,
		"aberration": 0.7,
		"saturation": 1.03,
		"contrast": 1.04,
		"lift": 0.008,
		"tint": Vector3(1.0, 1.0, 1.0),
		"tint_amount": 0.06,
		"shadow_tint": Vector3(0.92, 0.96, 1.06),
		"shadow_tint_amount": 0.18,
		"local_contrast": 0.28,
	})


func configure(params: Dictionary) -> void:
	if _mat == null:
		return
	for k in params.keys():
		_mat.set_shader_parameter(String(k), params[k])


## Reduce-motion / accessibility: drop grain and aberration.
func set_calm(calm: bool) -> void:
	if calm:
		configure({"grain_amount": 0.0, "aberration": 0.0})


## Build a grade for a chapter from its art profile. If the profile carries an
## explicit `cine` block that wins; otherwise the grade is DERIVED from the
## chapter's own fog colour and sun warmth, so all 16 chapters differ without
## anyone hand-authoring 16 more dictionaries.
static func params_for_profile(prof: Dictionary) -> Dictionary:
	var p := {
		"strength": 1.0,
		"vignette_amount": 0.30,
		"vignette_softness": 0.62,
		"grain_amount": 0.020,
		"aberration": 0.7,
		"saturation": 1.03,
		"contrast": 1.04,
		"lift": 0.008,
		"tint": Vector3(1.0, 1.0, 1.0),
		"tint_amount": 0.06,
		"shadow_tint": Vector3(0.92, 0.96, 1.06),
		"shadow_tint_amount": 0.18,
		"local_contrast": 0.28,
	}

	# --- derive from the chapter's own atmosphere -------------------------
	var fog: Dictionary = prof.get("fog", {})
	var fog_c: Color = fog.get("color", Color(0.62, 0.64, 0.67))
	var sun: Dictionary = prof.get("sun", {})
	var sun_c: Color = sun.get("color", Color(1, 0.96, 0.9))
	var sun_e := float(sun.get("energy", 1.1))

	# Warm sun -> warm tint; cold/dim sun -> cool shadows and a heavier vignette.
	var warmth := clampf(sun_c.r - sun_c.b, -0.5, 0.6)
	p["tint"] = Vector3(1.0 + warmth * 0.10, 1.0, 1.0 - warmth * 0.10)
	p["tint_amount"] = clampf(0.05 + absf(warmth) * 0.22, 0.04, 0.18)

	# Dark chapters get a stronger frame and cooler shadows; bright open
	# chapters get an airier one.
	var dark := clampf(1.0 - sun_e, -0.4, 0.9)
	p["vignette_amount"] = clampf(0.26 + dark * 0.34, 0.16, 0.52)
	p["shadow_tint"] = Vector3(
		clampf(0.88 + fog_c.r * 0.16, 0.82, 1.08),
		clampf(0.90 + fog_c.g * 0.14, 0.86, 1.06),
		clampf(0.96 + fog_c.b * 0.16, 0.90, 1.14))
	p["shadow_tint_amount"] = clampf(0.14 + dark * 0.16, 0.10, 0.32)

	# The compatibility renderer has no SSAO; a touch more local contrast and
	# grain stands in for the missing contact shading and hides GLES banding.
	if not QualityTier.supports_ssao():
		p["local_contrast"] = 0.40
		p["grain_amount"] = 0.026

	# An authored `cine` block always wins.
	var cine: Dictionary = prof.get("cine", {})
	for k in cine.keys():
		p[k] = cine[k]
	return p


## Attach a cinematic grade to any node.
static func attach(parent: Node, prof: Dictionary = {}) -> CinematicPostFX:
	var fx := CinematicPostFX.new()
	parent.add_child(fx)
	fx.configure(params_for_profile(prof))
	if Engine.get_main_loop() is SceneTree:
		var st := Engine.get_main_loop() as SceneTree
		var settings: Node = st.root.get_node_or_null("Settings")
		if settings != null and bool(settings.get("reduce_motion")):
			fx.set_calm(true)
	return fx
