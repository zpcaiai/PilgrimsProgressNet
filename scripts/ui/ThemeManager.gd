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

# The CJK font we ship, referenced at compile time so it is guaranteed to be
# bundled and loadable on every platform (incl. web). Used as the fallback when
# runtime discovery (AssetLib.font()) finds nothing.
const SHIPPED_CJK_FONT := preload("res://assets/fonts/NotoSansCJKsc-Subset.otf")


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
	var f: Font = AssetLib.font()
	if f == null:
		# Bulletproof fallback: the font is referenced at compile time (SHIPPED_CJK_FONT),
		# so it is always bundled and directly usable on web — where DirAccess folder
		# scans and sometimes ResourceLoader.exists() on the source path silently fail.
		f = SHIPPED_CJK_FONT
	if f != null:
		theme.default_font = f
		var where := f.resource_path if f.resource_path != "" else "(dynamic)"
		print("[ThemeManager] CJK font applied: ", where)
	else:
		print("[ThemeManager] no font found — using engine default (CJK will tofu).")
	get_tree().root.theme = theme
