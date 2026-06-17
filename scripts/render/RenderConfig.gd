extends RefCounted
class_name RenderConfig
## Global art-direction switch, driven by the chosen journey mode.
##
##   Children's Journey  -> oil-painting / storybook stylised look
##   Devout (adult)      -> natural realistic look
##
## is_realistic() == true  -> realistic: no oil Kuwahara post, no painting-as-sky
##   backdrop, no fantastical god-rays / halos / glowing cities; clean procedural
##   (or photo) sky, PBR materials, naturalistic lighting/fog/dressing. Realistic
##   environment photos in assets/scenes/realistic/<id>.* are used when present.
## is_realistic() == false -> the painterly / oil-painting showcase look.
##
## FORCE lets you override the per-mode behaviour for testing:
##   0 = auto (by journey mode)   1 = force realistic   2 = force oil
const FORCE := 0


## True when the world should render in the realistic style (Devout mode).
static func is_realistic() -> bool:
	if FORCE == 1:
		return true
	if FORCE == 2:
		return false
	return not _is_child_mode()


## Read the journey mode from the GameState autoload via the scene tree, so this
## stays valid in a static context (mirrors AssetLib._is_child_mode).
static func _is_child_mode() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gs: Node = (loop as SceneTree).root.get_node_or_null("GameState")
		if gs != null and gs.has_method("is_child_mode"):
			return bool(gs.call("is_child_mode"))
	return false
