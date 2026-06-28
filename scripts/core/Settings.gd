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


func save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)  # preserve other sections ([audio], [input], [video])
	cf.set_value("accessibility", "reduce_motion", reduce_motion)
	cf.set_value("accessibility", "colorblind", colorblind)
	cf.set_value("accessibility", "seen_controls", seen_controls)
	cf.set_value("accessibility", "teaching_mode", teaching_mode)
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
