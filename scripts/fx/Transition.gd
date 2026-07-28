extends CanvasLayer
## Transition — global scene-change veil, autoloaded as `Transition`.
##
## Two uses:
##   Transition.cover(cb)  — fade to black, run `cb` (swap the scene), then reveal.
##   (automatic)           — on EventBus.chapter_started it reveals FROM black so
##                           the instant chapter swap never "pops" into view.
##
## Works while the tree is paused (PROCESS_MODE_ALWAYS) and respects
## Settings.reduce_motion (snaps instead of fading).

const FADE := 0.55

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0.02, 0.02, 0.04, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	if EventBus.has_signal("chapter_started"):
		EventBus.chapter_started.connect(_on_chapter_started)


func _dur() -> float:
	return 0.001 if Settings.reduce_motion else FADE


func _on_chapter_started(_chapter_id: String) -> void:
	# The scene is already swapped by the time this fires — reveal from black.
	_veil.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(_veil, "color:a", 0.0, _dur())


## Fade to black and RETURN once the screen is covered. The caller then swaps
## the chapter; EventBus.chapter_started reveals from black on the other side.
##
## Before this existed, a chapter change was a hard cut: the old scene was freed
## and the new one added in the same frame, and the only softening was the
## reveal-from-black in _on_chapter_started — i.e. the fade sat on the WRONG
## side of the cut. The player watched the next chapter's geometry pop into
## existence and only then fade up from black. `await Transition.veil_out()`
## puts the fade where it belongs.
func veil_out(dur: float = -1.0) -> void:
	var d := _dur() if dur < 0.0 else (0.001 if Settings.reduce_motion else dur)
	if _veil == null or _veil.color.a >= 0.999:
		return
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, d)
	await tw.finished


## Fade to black, invoke `mid` (e.g. load a scene / return to title), then reveal.
func cover(mid: Callable = Callable()) -> void:
	if _busy:
		if mid.is_valid():
			mid.call()
		return
	_busy = true
	var d := _dur()
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 1.0, d)
	tw.tween_callback(func():
		if mid.is_valid():
			mid.call()
	)
	tw.tween_interval(0.05)
	tw.tween_property(_veil, "color:a", 0.0, d)
	tw.tween_callback(func(): _busy = false)
