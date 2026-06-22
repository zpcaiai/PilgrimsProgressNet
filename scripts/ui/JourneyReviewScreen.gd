extends CanvasLayer
class_name JourneyReviewScreen
## The closing remembrance at the Celestial City. When `journey_review_requested`
## (or `journey_completed`) is set, it fades in and lists the journey's grace beats
## from the player's flags -- remembrance, not a score. Added (hidden) by GlbChapter
## for celestial_city; reveals itself when the ending fires.

# Each beat: any of these flags present -> show the line.
const BEATS := [
	[["received_burden", "read_book"], "A burden you could not remove."],
	[["left_city"], "You left the City of Destruction."],
	[["accepted_help", "rescued_from_slough"], "Help lifted you from the mire."],
	[["burden_fallen", "burden_removed"], "The burden fell at the Cross."],
	[["received_armor", "has_armor"], "You were armed at Palace Beautiful."],
	[["defeated_apollyon", "stood_against_accuser"], "You stood against the Accuser."],
	[["survived_shadow_valley", "crossed_shadow"], "You walked the valley of shadow."],
	[["faithful_witnessed"], "Faithful's witness was remembered."],
	[["hopeful_joined", "has_companion_hopeful"], "Hopeful walked the rest of the way with you."],
	[["escaped_castle", "escaped_doubting_castle", "found_promise_key"], "Promise opened the prison of despair."],
	[["has_shepherd_map", "received_shepherd_warning"], "The Shepherds gave you sight and warning."],
	[["crossed_river"], "You crossed the last river."],
	[["journey_completed", "entered_city", "entered_celestial_city"], "The journey is received."],
]

var _shown: bool = false


func _ready() -> void:
	layer = 150
	visible = false


func _process(_delta: float) -> void:
	if _shown:
		return
	if GameState.has_flag("journey_review_requested") or GameState.has_flag("journey_completed"):
		_shown = true
		_build()


func _has_any(flags: Array) -> bool:
	for f in flags:
		if GameState.has_flag(String(f)):
			return true
	return false


func _build() -> void:
	visible = true
	EventBus.player_control_locked.emit(true)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "The Journey Received"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	box.add_child(_spacer(8))
	for beat in BEATS:
		if _has_any(beat[0]):
			var l := Label.new()
			l.text = "·  " + String(beat[1])
			l.add_theme_font_size_override("font_size", 20)
			box.add_child(l)

	box.add_child(_spacer(10))
	var coda := Label.new()
	coda.text = "The burden was gone. The road was finished. The welcome remained."
	coda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coda.add_theme_font_size_override("font_size", 18)
	box.add_child(coda)

	box.add_child(_spacer(14))
	var btn := Button.new()
	btn.text = "Continue"
	btn.pressed.connect(_on_continue)
	box.add_child(btn)

	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.92, 1.2)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_continue() -> void:
	EventBus.player_control_locked.emit(false)
	if EventBus.has_signal("ending_started"):
		EventBus.emit_signal("ending_started")
	queue_free()
