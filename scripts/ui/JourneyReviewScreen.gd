extends CanvasLayer
class_name JourneyReviewScreen
## The closing remembrance at the Celestial City. When `journey_review_requested`
## (or `journey_completed`) is set, it fades in and names the journey's grace beats
## from the player's own flags -- remembrance, not a score. Bilingual. Added
## (hidden) by GlbChapter for celestial_city; reveals itself when the ending fires.

# Each beat: [any-of-these-flags, english, chinese]. Ordered as the road runs.
const BEATS := [
	[["received_burden", "read_book"], "A burden you could not remove.", "一个你无法卸下的重担。"],
	[["left_city"], "You left the City of Destruction.", "你离开了将亡之城。"],
	[["obstinate_left"], "You answered Obstinate, and let the burning city go.", "你答复了固执，任那焚城远去。"],
	[["accepted_help", "rescued_from_slough"], "Help lifted you from the mire.", "「帮助」把你从泥沼中拉起。"],
	[["used_promise_hope", "used_promise_faith", "used_promise_perseverance"], "You grasped the stones of promise in the mire.", "你在泥潭里握住了应许之石。"],
	[["passed_wicket_gate"], "You knocked, and the narrow gate opened.", "你叩门，窄门就开了。"],
	[["burden_fallen", "burden_removed"], "The burden fell at the Cross.", "重担在十字架前滚落。"],
	[["met_interpreter", "left_interpreter"], "You let the Interpreter's rooms teach your heart.", "你让解经者的房间教导你的心。"],
	[["received_armor", "has_armor"], "You were armed at Palace Beautiful.", "你在华美宫披上了军装。"],
	[["defeated_apollyon", "stood_against_accuser"], "You stood against the Accuser, Apollyon.", "你抵挡了那控告者亚玻伦，站立得住。"],
	[["survived_shadow_valley", "crossed_shadow"], "You walked the valley of the shadow of death.", "你走过了死荫的幽谷。"],
	[["faithful_witnessed", "faithful_lost"], "Faithful's witness was remembered.", "忠信的见证，被纪念。"],
	[["entered_vanity_fair"], "You refused what Vanity Fair was selling.", "你拒绝了浮华集所贩卖的。"],
	[["hopeful_joined", "has_companion_hopeful"], "Hopeful walked the rest of the way with you.", "盼望陪你走完了余下的路。"],
	[["escaped_castle", "escaped_doubting_castle", "found_promise_key"], "The Promise opened the prison of despair.", "应许打开了绝望的牢狱。"],
	[["met_shepherds", "has_shepherd_map", "received_shepherd_warning"], "The Shepherds gave you sight and warning.", "牧人赐你远象，也给你警戒。"],
	[["resisted_sleep"], "You did not sleep on the Enchanted Ground.", "在魔境之地，你没有沉睡。"],
	[["worshipped_at_chapel"], "You knelt to worship in the wayside chapels.", "你在路边的小堂里跪下礼拜。"],
	[["crossed_river", "river_memory_recalled"], "You crossed the last river.", "你渡过了那最后的河。"],
	[["journey_completed", "entered_city", "entered_celestial_city"], "The journey is received.", "这旅程，被接纳了。"],
]

# Chapters that carry a Scripture Gate, for the "verses answered" tally.
const SCRIPTURE_CHAPTERS := [
	"city_of_destruction", "wilderness_road", "slough_of_despond", "wicket_gate",
	"cross_and_tomb", "interpreter_house", "hill_difficulty", "palace_beautiful",
	"valley_humiliation", "valley_shadow_death", "vanity_fair", "doubting_castle",
	"delectable_mountains", "enchanted_ground", "river_of_death", "celestial_city",
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
	var zh := LocaleManager.is_zh()

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	center.add_child(box)

	var title := Label.new()
	title.text = "所行之路，蒙了纪念" if zh else "The Journey Received"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	box.add_child(title)

	box.add_child(_spacer(8))
	for beat in BEATS:
		if _has_any(beat[0]):
			var l := Label.new()
			l.text = "·  " + String(beat[2] if zh else beat[1])
			l.add_theme_font_size_override("font_size", 20)
			box.add_child(l)

	# Tally of Scripture Gates answered along the road.
	var verses := 0
	for cid in SCRIPTURE_CHAPTERS:
		if GameState.has_flag("scripture_" + cid):
			verses += 1
	if verses > 0:
		var sl := Label.new()
		sl.text = ("·  你在 %d 道经文之门前认出了真道。" % verses) if zh else ("·  You answered the Word rightly at %d Scripture Gates." % verses)
		sl.add_theme_font_size_override("font_size", 20)
		sl.add_theme_color_override("font_color", Color(0.8, 0.86, 0.98))
		box.add_child(sl)
	var known_cards := ScriptureMemory.known_cards()
	if known_cards.size() > 0:
		var remembered: Array = []
		for i in range(min(known_cards.size(), 3)):
			var card: Dictionary = known_cards[i]
			var theme := String(card.get("theme_zh", card.get("theme_en", ""))) if zh else LocaleManager.bilingual(String(card.get("theme_zh", "")), String(card.get("theme_en", "")))
			remembered.append("%s %s" % [String(card.get("ref", "")), theme])
		var vl := Label.new()
		vl.text = "·  记在心里的经文：%s%s" % [
			"；".join(PackedStringArray(remembered)),
			(" 等 %d 张。" % known_cards.size()) if known_cards.size() > 3 else "。"
		]
		vl.add_theme_font_size_override("font_size", 18)
		vl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.58))
		box.add_child(vl)

	box.add_child(_spacer(10))
	var coda := Label.new()
	coda.text = "重担已经卸下。道路已经走完。那欢迎，长存。" if zh else "The burden was gone. The road was finished. The welcome remained."
	coda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coda.add_theme_font_size_override("font_size", 18)
	box.add_child(coda)

	box.add_child(_spacer(14))
	var btn := Button.new()
	btn.text = "继续 Continue"
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_continue)
	box.add_child(btn)

	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.93, 1.2)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_continue() -> void:
	EventBus.player_control_locked.emit(false)
	if EventBus.has_signal("ending_started"):
		EventBus.emit_signal("ending_started")
	queue_free()
