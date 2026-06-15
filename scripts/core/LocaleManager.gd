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

var locale: String = "en"               # "zh" or "en"
var _t: Dictionary = {}                  # key -> {"en": ..., "zh": ...}


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
		if s == "zh" or s == "en":
			return s
	return _detect()


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
	return "English" if locale == "zh" else "中文"


## Translate a key. Fallback chain: current locale -> the other locale -> the
## supplied English fallback -> the key itself.
func t(key: String, fallback: String = "") -> String:
	var e: Variant = _t.get(key, null)
	if e is Dictionary:
		var v := String(e.get(locale, ""))
		if v != "":
			return v
		var other := String(e.get("en" if locale == "zh" else "zh", ""))
		if other != "":
			return other
	return fallback if fallback != "" else key
