extends CanvasLayer
## TeachingGuidePanel  (autoloaded as "TeachingGuidePanel")
## Batch 7 / Skill 54 — Sunday-school / catechism teaching mode.
##
## Reads data/teaching_guides/<chapter_id>.json (built by
## tools/data_gen/build_teaching_guides.py) and shows a bilingual overlay with
## the chapter's original-story summary, spiritual theme, Bible references,
## audience-tiered discussion questions, teacher notes, and reflection + prayer
## prompts.
##
## It self-shows after a chapter completes WHEN Settings.teaching_mode is on
## (EventBus.chapter_completed), and can be opened at any time with F1 for the
## current chapter (handy for teachers/preview). Fully optional and additive:
## if a guide file is missing it simply does nothing. Locale follows
## TranslationServer (zh / en).

const GUIDE_DIR := "res://data/teaching_guides/"

var _label: RichTextLabel
var _root: Control
var _visible_for: String = ""


func _ready() -> void:
	layer = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide_panel()
	if Engine.has_singleton("EventBus") or get_node_or_null("/root/EventBus") != null:
		var bus := get_node_or_null("/root/EventBus")
		if bus != null and bus.has_signal("chapter_completed"):
			bus.chapter_completed.connect(_on_chapter_completed)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 560)
	panel.offset_left = -360
	panel.offset_top = -280
	panel.offset_right = 360
	panel.offset_bottom = 280
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_label)

	var close := Button.new()
	close.text = "关闭 / Close  (Esc)"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide_panel)
	vbox.add_child(close)


func _zh() -> bool:
	return TranslationServer.get_locale().begins_with("zh")


func _loc(d: Dictionary, base: String) -> String:
	var suffix := "_zh" if _zh() else "_en"
	if d.has(base + suffix):
		return String(d[base + suffix])
	if d.has(base + "_en"):
		return String(d[base + "_en"])
	return String(d.get(base + "_zh", ""))


func _audience_label(a: String) -> String:
	var zh := {
		"children": "儿童", "youth": "青少年", "seekers": "慕道友",
		"adult": "成人", "small_group": "小组",
	}
	if _zh():
		return String(zh.get(a, a))
	return a.capitalize()


func _on_chapter_completed(chapter_id: String) -> void:
	var s := get_node_or_null("/root/Settings")
	if s != null and s.get("teaching_mode"):
		open_for(chapter_id)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_toggle_current()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _root.visible:
			hide_panel()
			get_viewport().set_input_as_handled()


func _toggle_current() -> void:
	if _root.visible:
		hide_panel()
		return
	var cm := get_node_or_null("/root/ChapterManager")
	var cid := ""
	if cm != null:
		cid = String(cm.get("current_chapter_id"))
	if cid != "":
		open_for(cid)


## Public: load + show the teaching guide for a chapter id. No-op if absent.
func open_for(chapter_id: String) -> void:
	var data := _load_guide(chapter_id)
	if data.is_empty():
		return
	_label.text = _compose(data)
	_visible_for = chapter_id
	_root.visible = true
	visible = true


func hide_panel() -> void:
	_root.visible = false
	visible = false


func _load_guide(chapter_id: String) -> Dictionary:
	var path := GUIDE_DIR + chapter_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _compose(d: Dictionary) -> String:
	var hdr_summary := "原著剧情" if _zh() else "The Story"
	var hdr_theme := "属灵主题" if _zh() else "Spiritual Theme"
	var hdr_refs := "经文参考" if _zh() else "Scripture"
	var hdr_q := "讨论问题" if _zh() else "Discussion Questions"
	var hdr_notes := "教师提示" if _zh() else "Teacher's Notes"
	var hdr_reflect := "默想回应" if _zh() else "Reflection"
	var hdr_prayer := "祷告" if _zh() else "Prayer"

	var out := PackedStringArray()
	out.append("[b][font_size=26]%s[/font_size][/b]" % _loc(d, "title"))
	var alt_title := String(d.get("title_en" if _zh() else "title_zh", ""))
	out.append("[color=#c9b88a]%s[/color]\n" % alt_title)

	out.append("[b]%s[/b]" % hdr_summary)
	out.append(_loc(d, "story_summary") + "\n")

	out.append("[b]%s[/b]" % hdr_theme)
	out.append(_loc(d, "spiritual_theme") + "\n")

	out.append("[b]%s[/b]" % hdr_refs)
	for r in d.get("bible_references", []):
		var rd := r as Dictionary
		var ref := _loc(rd, "reference")
		var lab := _loc(rd, "label")
		var note := _loc(rd, "note")
		out.append("• [b]%s[/b] — %s\n   [i]%s[/i]" % [ref, lab, note])
	out.append("")

	out.append("[b]%s[/b]" % hdr_q)
	var qi := 0
	for q in d.get("discussion_questions", []):
		var qd := q as Dictionary
		qi += 1
		out.append("%d. [color=#9fb4d0](%s)[/color] %s" % [qi, _audience_label(String(qd.get("audience", ""))), _loc(qd, "question")])
	out.append("")

	out.append("[b]%s[/b]" % hdr_notes)
	var notes_key := "teacher_notes_zh" if _zh() else "teacher_notes_en"
	for n in d.get(notes_key, d.get("teacher_notes_en", [])):
		out.append("– " + String(n))
	out.append("")

	out.append("[b]%s[/b]" % hdr_reflect)
	out.append(_loc(d, "reflection_prompt") + "\n")

	out.append("[b]%s[/b]" % hdr_prayer)
	out.append("[i]%s[/i]" % _loc(d, "prayer_prompt"))

	return "\n".join(out)
