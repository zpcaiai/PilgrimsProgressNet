extends Node
## LocaleManager (autoload)
## Bilingual zh / en support. Holds the current language, persists the choice,
## and serves UI strings from res://assets/i18n/ui.json. Live-switchable:
## set_locale()/toggle() emit EventBus.locale_changed so code-built UIs can
## rebuild in the new language.
##
## Usage in UI code:
##     label.text = LocaleManager.t("hud.faith", "Faith")
## The second argument is the English fallback shown if the table lacks the key
## (so the game still reads sensibly even before the table is complete).

const SETTINGS := "user://locale.cfg"
const TABLE := "res://assets/i18n/ui.json"

var locale: String = "zh"               # "zh" or "en" (defaults to Chinese)
var _t: Dictionary = {}                  # key -> {"en": ..., "zh": ...}
const MISSING_ZH_PREFIX := "中文待补："


func _ready() -> void:
	_load_table()
	locale = _load_saved()
	_apply_translation_server()


func _load_table() -> void:
	if not FileAccess.file_exists(TABLE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	if parsed is Dictionary:
		_t = parsed


func _detect() -> String:
	return "zh" if OS.get_locale().begins_with("zh") else "en"


func _load_saved() -> String:
	if FileAccess.file_exists(SETTINGS):
		var s := FileAccess.get_file_as_string(SETTINGS).strip_edges()
		if s == "zh":
			return s
		if s == "en":
			# This build is Chinese-first; reopen in Chinese even if an older
			# settings file had English saved.
			return "zh"
	# Default to Chinese on first open (no saved choice yet).
	return "zh"


func _apply_translation_server() -> void:
	# Keep Godot's own tr() in sync too (for any scene-based strings).
	TranslationServer.set_locale("zh_CN" if locale == "zh" else "en")


func is_zh() -> bool:
	return locale == "zh"


func set_locale(loc: String) -> void:
	if (loc != "zh" and loc != "en") or loc == locale:
		return
	locale = loc
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f != null:
		f.store_string(loc)
		f.close()
	_apply_translation_server()
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.emit(loc)


func toggle() -> void:
	set_locale("en" if locale == "zh" else "zh")


## A short label for a language-switch button (shows the language you'd switch TO).
func switch_label() -> String:
	return "中英" if locale == "zh" else "中文"


func has_chinese(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if (code >= 0x3400 and code <= 0x9FFF) or (code >= 0xF900 and code <= 0xFAFF):
			return true
	return false


func zh_or_mixed(text: String) -> String:
	if text == "" or has_chinese(text):
		return text
	return MISSING_ZH_PREFIX + text


func bilingual(zh: String, en: String) -> String:
	if zh != "" and en != "" and zh != en:
		return zh + " / " + en
	if zh != "":
		return zh
	return zh_or_mixed(en)


func mixed_label(zh: String, en: String) -> String:
	if zh != "" and en != "" and zh != en:
		return zh + " " + en
	if zh != "":
		return zh
	return zh_or_mixed(en)


func npc_label(name: String) -> String:
	var e: Variant = _t.get("npc." + name, null)
	if e is Dictionary:
		var zh := String(e.get("zh", ""))
		var en := String(e.get("en", name))
		return mixed_label(zh, en)
	return zh_or_mixed(name)


## Translate a key. Fallback chain: current locale -> the other locale -> the
## supplied English fallback -> the key itself.
func t(key: String, fallback: String = "") -> String:
	var e: Variant = _t.get(key, null)
	if e is Dictionary:
		var zh := String(e.get("zh", ""))
		var en := String(e.get("en", ""))
		if locale == "zh":
			if zh != "":
				return zh
			return zh_or_mixed(en if en != "" else fallback)
		return bilingual(zh, en if en != "" else fallback)
	return zh_or_mixed(fallback if fallback != "" else key)
