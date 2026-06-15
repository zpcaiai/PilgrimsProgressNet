extends Node
## ThemeManager (autoload)
## Applies a project-wide UI Theme at startup and — crucially — injects a
## CJK-capable font if one is present in res://assets/fonts/, so Chinese chat,
## player names, and any localized text render instead of tofu boxes (□□□).
##
## Fully existence-checked: with no font and no theme.tres present it sets a
## harmless empty theme and the game looks exactly as before. Drop any .ttf/.otf
## (e.g. Noto Sans CJK / Source Han Sans) into res://assets/fonts/ and restart —
## it is picked up automatically, no code change needed.

func _ready() -> void:
	var theme: Theme = null
	if ResourceLoader.exists("res://assets/ui/theme.tres"):
		var t: Resource = load("res://assets/ui/theme.tres")
		if t is Theme:
			theme = t
	if theme == null:
		theme = Theme.new()
	if theme.default_font_size <= 0:
		theme.default_font_size = 16
	var f := AssetLib.font()
	if f != null:
		theme.default_font = f
		var where := f.resource_path if f.resource_path != "" else "(dynamic)"
		print("[ThemeManager] CJK font applied: ", where)
	else:
		print("[ThemeManager] no font in res://assets/fonts/ — using engine default (CJK will tofu).")
	get_tree().root.theme = theme
