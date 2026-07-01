extends Node
## App / accessibility preferences (distinct from game-save flags), autoloaded
## as `Settings` and persisted to user://settings.cfg under [accessibility].
## Read by Juice (reduce_motion), CombatHUD (colorblind), and the Options screen.
## Kept tiny and dependency-free so anything can read it at runtime.

const PATH := "user://settings.cfg"

var reduce_motion: bool = false   # disables screen shake + hit-stop
var colorblind: bool = false      # colour-blind-safe HUD palette (blue/orange)
var seen_controls: bool = false   # first-run control hint shown?
var teaching_mode: bool = true    # Learning-first mode: show the chapter teaching guide on completion (F1 to open anytime)
var tts: bool = false              # read narration + dialogue aloud (screen-reader style)

var _tts_voice: String = ""


func _ready() -> void:
	load_prefs()


func load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	reduce_motion = bool(cf.get_value("accessibility", "reduce_motion", reduce_motion))
	colorblind = bool(cf.get_value("accessibility", "colorblind", colorblind))
	seen_controls = bool(cf.get_value("accessibility", "seen_controls", seen_controls))
	teaching_mode = bool(cf.get_value("accessibility", "teaching_mode", teaching_mode))
	tts = bool(cf.get_value("accessibility", "tts", tts))


func save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)  # preserve other sections ([audio], [input], [video])
	cf.set_value("accessibility", "reduce_motion", reduce_motion)
	cf.set_value("accessibility", "colorblind", colorblind)
	cf.set_value("accessibility", "seen_controls", seen_controls)
	cf.set_value("accessibility", "teaching_mode", teaching_mode)
	cf.set_value("accessibility", "tts", tts)
	cf.save(PATH)


func set_reduce_motion(v: bool) -> void:
	reduce_motion = v
	save_prefs()


func set_colorblind(v: bool) -> void:
	colorblind = v
	save_prefs()


func mark_controls_seen() -> void:
	seen_controls = true
	save_prefs()


func set_teaching_mode(v: bool) -> void:
	teaching_mode = v
	save_prefs()


func set_tts(v: bool) -> void:
	tts = v
	save_prefs()
	if not v and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()


func _tts_pick_voice() -> String:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return ""
	var want := "zh" if LocaleManager.is_zh() else "en"
	var voices := DisplayServer.tts_get_voices()
	for v in voices:
		if String((v as Dictionary).get("language", "")).begins_with(want):
			return String((v as Dictionary).get("id", ""))
	return String((voices[0] as Dictionary).get("id", "")) if voices.size() > 0 else ""


## Read text aloud when TTS is on and supported (else a silent no-op). Interrupts
## the previous line so speech tracks the on-screen narration/dialogue.
func speak(text: String) -> void:
	if not tts or text.strip_edges() == "":
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if _tts_voice == "":
		_tts_voice = _tts_pick_voice()
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _tts_voice)
