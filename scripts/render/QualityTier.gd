extends RefCounted
class_name QualityTier
## Runtime render-tier detection — the single place that answers "how much can
## this build afford?".
##
## The project now ships TWO rendering methods (see project.godot):
##
##   desktop  -> forward_plus   (Vulkan/Metal: SSAO, SSIL, SDFGI, SSR, volumetric
##                               fog, real soft shadows, TAA, point-light shadows)
##   web/mob  -> gl_compatibility (GLES3: none of the above)
##
## Every renderer-specific feature in the codebase asks this class first instead
## of assuming a renderer, so the same scene code produces the best picture the
## current build can actually draw. Nothing here allocates; it is a pure static
## façade over RenderingServer, cached after the first query.
##
##   QualityTier.is_forward_plus()  -> real GI / SSAO / volumetrics available
##   QualityTier.tier()             -> "high" | "mid" | "low"
##   QualityTier.mesh_detail()      -> 0.55 .. 1.0 multiplier for procedural
##                                     mesh subdivision (characters, props)
##   QualityTier.allow_point_shadows() / allow_character_shadows()

const TIER_HIGH := "high"
const TIER_MID := "mid"
const TIER_LOW := "low"

## Override for testing: "" = auto, else one of TIER_*.
const FORCE := ""

static var _method: String = ""
static var _tier: String = ""


## "forward_plus" | "mobile" | "gl_compatibility" (lower-cased, never empty).
static func rendering_method() -> String:
	if _method != "":
		return _method
	var m := ""
	if ClassDB.class_exists("RenderingServer"):
		# Godot 4.3+ exposes the method actually in use (which can differ from the
		# project setting when a fallback kicked in).
		if RenderingServer.has_method("get_current_rendering_method"):
			m = String(RenderingServer.call("get_current_rendering_method"))
	if m == "":
		m = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	_method = m.to_lower()
	return _method


static func is_forward_plus() -> bool:
	return rendering_method() == "forward_plus"


## True on any renderer backed by a RenderingDevice (forward_plus or mobile),
## i.e. where compute-based effects exist at all.
static func has_rendering_device() -> bool:
	return rendering_method() != "gl_compatibility"


static func is_web() -> bool:
	return OS.has_feature("web")


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]


## "high" (forward_plus desktop) / "mid" (compat desktop) / "low" (web, mobile).
static func tier() -> String:
	if FORCE != "":
		return FORCE
	if _tier != "":
		return _tier
	if is_web() or is_mobile():
		_tier = TIER_LOW
	elif is_forward_plus():
		_tier = TIER_HIGH
	else:
		_tier = TIER_MID
	return _tier


static func is_high() -> bool:
	return tier() == TIER_HIGH


static func is_low() -> bool:
	return tier() == TIER_LOW


# ---------------------------------------------------------------- capabilities

## Screen-space AO / indirect light / reflections / SDFGI / volumetric fog all
## require a RenderingDevice renderer; on gl_compatibility they are set on the
## Environment and silently dropped, which is wasted authoring.
static func supports_ssao() -> bool:
	return has_rendering_device()


static func supports_ssil() -> bool:
	return is_forward_plus()


static func supports_sdfgi() -> bool:
	return is_forward_plus() and not is_low()


static func supports_ssr() -> bool:
	return is_forward_plus()


static func supports_volumetric_fog() -> bool:
	return is_forward_plus()


## Omni/spot shadow maps are affordable on desktop, ruinous on web where every
## chapter carries 20-45 point lights.
static func allow_point_shadows() -> bool:
	return is_high()


## How many of a chapter's point lights may cast shadows (nearest-first).
static func point_shadow_budget() -> int:
	match tier():
		TIER_HIGH:
			return 6
		TIER_MID:
			return 2
		_:
			return 0


static func allow_character_shadows() -> bool:
	return not is_low()


# ---------------------------------------------------------------- mesh budgets

## Multiplier applied to procedural mesh subdivision (characters, props).
static func mesh_detail() -> float:
	match tier():
		TIER_HIGH:
			return 1.0
		TIER_MID:
			return 0.85
		_:
			return 0.6


## Subdivision helper: scales `full` by mesh_detail() and clamps to a sane floor.
static func segments(full: int, floor_v: int = 6) -> int:
	return maxi(floor_v, int(round(float(full) * mesh_detail())))


## Whether characters get the extra readability geometry (brows, mouth, elbows,
## separate hair strands). Off on the lowest tier to keep web draw calls down.
static func character_extras() -> bool:
	return not is_low()


## Whether the per-chapter cinematic establishing shot plays.
static func allow_cinematic_intro() -> bool:
	return true


## Debug one-liner for the F3 overlay / logs.
static func describe() -> String:
	return "%s / %s (detail %.2f, point-shadows %d)" % [
		rendering_method(), tier(), mesh_detail(), point_shadow_budget()]
