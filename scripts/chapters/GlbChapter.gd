extends ChapterBase
class_name GlbChapter
## Chapter base that builds the world from the imported low-poly GLB
## (assets/imported_scenes/<id>.glb) via ImportedSceneBinder, instead of the old
## procedural greybox. If the GLB cannot be loaded, it falls back to the chapter's
## procedural build (_build_procedural) so the game is never left broken.
##
## Each chapter script now: `extends GlbChapter` and keeps its old geometry under
## `_build_procedural()` (renamed from `_build_chapter`).

var _used_glb: bool = false


func _build_chapter() -> void:
	if _prefer_procedural():
		_build_procedural()
		return
	var data := ChapterManager.get_current_chapter_data()
	var glb_path := String(data.get("imported_scene_path", ""))
	var spawn := ImportedSceneBinder.bind_scene(self, glb_path)
	if spawn.y <= -9000.0:
		# GLB unavailable (not imported yet, or load failed) -> procedural build.
		push_warning("[GlbChapter] %s: GLB NOT loaded (%s) -> procedural fallback"
			% [ChapterManager.current_chapter_id, glb_path])
		EventBus.toast("[占位] %s：GLB 未导入，回退到程序化场景"
			% ChapterManager.current_chapter_id)
		_build_procedural()
		return
	_used_glb = true
	push_warning("[GlbChapter] %s: GLB loaded, spawn=%s"
		% [ChapterManager.current_chapter_id, str(spawn)])
	# Always have a sky/sun; the world-rebuild pass refines it from the art profile.
	setup_environment(Color(0.5, 0.55, 0.62), Color(0.58, 0.58, 0.6), 0.7)
	_spawn_position = spawn
	spawn_player(spawn)
	_attach_chapter_system()


## Per-chapter scratch-meter system (sleepiness / vanity / river depth) for the
## chapters that use one.
func _attach_chapter_system() -> void:
	match ChapterManager.current_chapter_id:
		"slough_of_despond":
			add_child(MudSystem.new())
		"enchanted_ground":
			add_child(SleepinessSystem.new())
		"vanity_fair":
			add_child(VanityPressureSystem.new())
		"river_of_death":
			add_child(RiverDepthSystem.new())
		"celestial_city":
			add_child(JourneyReviewScreen.new())


## Override in each chapter with the original procedural geometry. Default no-op
## (the GLB carries the scene).
func _build_procedural() -> void:
	pass


## Chapters can override to force the hand-built procedural scene instead of the
## imported GLB (e.g. when a bespoke grounded layout is wanted).
func _prefer_procedural() -> bool:
	return false


## When the GLB is used, keep atmosphere (environment + lighting + painterly post)
## but skip procedural set-dressing / bespoke centrepiece, which would clash with
## the imported geometry.
func _apply_world_rebuild() -> void:
	if not _used_glb:
		super._apply_world_rebuild()
		return
	var prof := ChapterArtProfiles.for_chapter(ChapterManager.current_chapter_id)
	_apply_environment(prof)
	_apply_lighting(prof)
	if not RenderConfig.is_realistic():
		_attach_postfx(prof.get("post", {}))
	# Atmospheric-only dressing (mist / light shafts / fire / smoke) layered onto
	# the imported GLB. Structural dressing (rock, ridge, trees, walls...) is baked
	# into the GLB itself, so it is skipped here to avoid duplicating geometry.
	_apply_atmospheric_dressing(prof.get("dressing", []))
	# Gentle distance fog so the finite chapter ground fades into the sky at the
	# horizon (removes the "floating slab" look) while the nearby scene stays clear.
	var env := _find_or_make_env()
	if env != null:
		env.fog_enabled = true
		env.fog_density = 0.011
		env.fog_light_color = Color(0.62, 0.64, 0.70)
		env.fog_sky_affect = 0.25


## Apply only the atmospheric ops from a chapter's art-profile dressing list, so
## GLB chapters still get authored mist, god-rays, fire and smoke without the
## structural props (which the GLB already carries). Stylised mode only.
func _apply_atmospheric_dressing(list: Array) -> void:
	if RenderConfig.is_realistic():
		return
	var atmos := ["mist", "shaft", "fire", "smoke"]
	for item in list:
		if item is Dictionary and String(item.get("op", "")) in atmos:
			_dress_one(item)


## GLB chapters render the real 3D greybox world, so suppress the 2D painting /
## photo panorama sky. (Those backdrops are aerial images wrapped around the
## scene, which makes the pilgrim look like it floats above a flat city.) The
## procedural fallback keeps the original backdrop.
func _attach_backdrop() -> void:
	if _used_glb or _prefer_procedural():
		return
	super._attach_backdrop()


func _attach_realistic_backdrop() -> void:
	if _used_glb or _prefer_procedural():
		return
	super._attach_realistic_backdrop()
