extends CanvasLayer
class_name DarkVignette
## Reusable edge-darkening overlay for dark / oppressive scenes. Build it, set an
## optional edge_color (warm for heat / candlelight, cold for dread), add it as a
## child, then call set_intensity(0..1) each frame; the overlay smooths its alpha
## toward that value, so callers drive it straight from a fear / snuff / despair /
## drowse signal without managing the easing themselves.

@export var max_alpha: float = 0.75
@export var smooth: float = 4.0
## The colour the screen edges drown toward. Default black; tint warm or cold to
## colour the mood of the scene.
@export var edge_color: Color = Color(0, 0, 0)

var _rect: TextureRect = null
var _grad: Gradient = null
var _target: float = 0.0


func _ready() -> void:
	layer = 8
	_grad = Gradient.new()
	_grad.offsets = PackedFloat32Array([0.45, 1.0])
	_apply_edge_color()
	var gt := GradientTexture2D.new()
	gt.gradient = _grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_rect = TextureRect.new()
	_rect.texture = gt
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate = Color(1, 1, 1, 0)
	add_child(_rect)


func _apply_edge_color() -> void:
	if _grad == null:
		return
	var c := edge_color
	_grad.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 1.0)])


## Re-tint the edges at runtime (warm / cold). Safe before or after _ready().
func set_edge_color(c: Color) -> void:
	edge_color = c
	_apply_edge_color()


## Drive the darkness from any 0..1 signal; the overlay eases toward it.
func set_intensity(v: float) -> void:
	_target = clampf(v, 0.0, 1.0) * max_alpha


func _process(delta: float) -> void:
	if is_instance_valid(_rect):
		_rect.modulate.a = lerp(_rect.modulate.a, _target, clampf(delta * smooth, 0.0, 1.0))
