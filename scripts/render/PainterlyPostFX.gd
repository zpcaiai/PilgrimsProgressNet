extends CanvasLayer
class_name PainterlyPostFX
## Full-screen painterly post-process (oil painting / storybook).
##
## One cheap full-rect ColorRect running assets/shaders/painterly.gdshader,
## sitting on a high CanvasLayer above the 3D viewport so it grades the whole
## frame. Mode-aware: a firmer, cooler "oil painting" in Devout mode; a softer,
## warmer "storybook" wash in the Children's Journey.
##
## Fully inert if the shader file is absent (the scene still renders raw), so
## the project keeps the existing greybox-friendly "works with any subset of
## assets" guarantee.

const SHADER_PATH := "res://assets/shaders/painterly.gdshader"

var _rect: ColorRect = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	# Sit above the 3D world (the viewport base, behind every CanvasLayer) but
	# BELOW all game UI, which lives on layers 9..22 (HUD=10, dialogue=16, menus
	# =20, ...). hint_screen_texture then captures only the rendered 3D frame, so
	# the painterly grade never smears HUD text or dialogue panels.
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
	_apply_mode_defaults()


## The Children's Journey oil-painting look. This post-process is now attached
## ONLY in Children's mode (Devout mode renders realistically with no filter), so
## the defaults are a warm, rich, kid-friendly oil wash. Per-chapter profiles
## refine these via configure().
func _apply_mode_defaults() -> void:
	if _mat == null:
		return
	_apply_param("strength", 0.9)
	_apply_param("saturation", 1.14)
	_apply_param("contrast", 1.04)
	_apply_param("brightness", 1.03)
	_apply_param("tint", Vector3(1.0, 0.97, 0.9))
	_apply_param("tint_amount", 0.1)
	_apply_param("vignette_amount", 0.24)
	_apply_param("grain_amount", 0.03)
	_apply_param("brush", 1.2)


## Per-chapter overrides (e.g. {"tint": Vector3(...), "vignette_amount": 0.5}).
func configure(params: Dictionary) -> void:
	for k in params.keys():
		_apply_param(String(k), params[k])


func _apply_param(param: String, value) -> void:
	if _mat != null:
		_mat.set_shader_parameter(param, value)


## Attach a post-process layer to any node, optionally with per-chapter params.
static func attach(parent: Node, params: Dictionary = {}) -> PainterlyPostFX:
	var fx := PainterlyPostFX.new()
	parent.add_child(fx)
	if not params.is_empty():
		fx.configure(params)
	return fx
