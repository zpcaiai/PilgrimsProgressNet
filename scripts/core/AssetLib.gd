extends RefCounted
class_name AssetLib
## AssetLib
## Existence-checked loaders for optional visual assets (textures, portraits,
## chapter backdrops, particle sprites, animation flipbooks).
##
## Like AudioManager, this works with ZERO asset files present: every getter
## checks ResourceLoader.exists() and returns null on a miss, so callers fall
## back to the procedural greybox look. Drop matching .png files into the
## folders below and they appear automatically — no further code changes.
##
## Expected layout (all optional):
##   res://assets/textures/ground/<chapter_id>.png   per-chapter ground texture
##   res://assets/scenes/<chapter_id>.png            per-chapter title-card art
##   res://assets/characters/<stem>.png              dialogue portraits
##   res://assets/textures/particles/<name>.png      soft particle sprites
##   res://assets/ui/<name>.png                      title key art, icons
##   res://assets/anim/<name>.png                    horizontal flipbook sheets

const GROUND_DIR := "res://assets/textures/ground/"
const SCENE_DIR := "res://assets/scenes/"
const CHAR_DIR := "res://assets/characters/"
const PARTICLE_DIR := "res://assets/textures/particles/"
const UI_DIR := "res://assets/ui/"
const ANIM_DIR := "res://assets/anim/"

# Dialogue speaker display name -> portrait file stem.
const SPEAKER_MAP := {
	"Pilgrim": "pilgrim",
	"Evangelist": "evangelist",
	"Help": "help",
	"Goodwill": "goodwill",
	"Hopeful": "hopeful",
	"Apollyon": "apollyon",
	"The Interpreter": "the_interpreter",
	"The Shepherds": "the_shepherds",
	"Watchful": "watchful",
	"Obstinate": "obstinate",
	"Pliable": "pliable",
	"Your Family": "your_family",
}


static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r: Resource = load(path)
	return r as Texture2D


static func ground(chapter_id: String) -> Texture2D:
	return tex(GROUND_DIR + chapter_id + ".png")


static func scene_art(chapter_id: String) -> Texture2D:
	# Children's-journey variant: prefer "<chapter>_child.png" in child mode,
	# falling back to the standard chapter art when no child variant exists.
	if _is_child_mode():
		var child := tex(SCENE_DIR + chapter_id + "_child.png")
		if child != null:
			return child
	return tex(SCENE_DIR + chapter_id + ".png")


static func particle(particle_name: String) -> Texture2D:
	return tex(PARTICLE_DIR + particle_name + ".png")


static func ui(ui_name: String) -> Texture2D:
	return tex(UI_DIR + ui_name + ".png")


static func portrait(speaker: String) -> Texture2D:
	var stem := String(SPEAKER_MAP.get(speaker, ""))
	if stem == "":
		stem = speaker.to_lower().replace(" ", "_")
	# Children's-journey variant: prefer "<stem>_child.png" in child mode, and
	# fall back to the standard portrait when no child variant exists.
	if _is_child_mode():
		var child := tex(CHAR_DIR + stem + "_child.png")
		if child != null:
			return child
	return tex(CHAR_DIR + stem + ".png")


## True when the pilgrim chose the gentler "Children's Journey". Read from the
## GameState autoload via the scene tree so this stays valid in a static context.
static func _is_child_mode() -> bool:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gs: Node = (loop as SceneTree).root.get_node_or_null("GameState")
		if gs != null and gs.has_method("is_child_mode"):
			return bool(gs.call("is_child_mode"))
	return false


static func anim_sheet(anim_name: String) -> Texture2D:
	return tex(ANIM_DIR + anim_name + ".png")


## Build SpriteFrames from a horizontal flipbook sheet. Returns null if absent.
static func sprite_frames(anim_name: String, hframes: int, fps: float = 12.0, loop: bool = true) -> SpriteFrames:
	var t := anim_sheet(anim_name)
	if t == null or hframes <= 0:
		return null
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var fw := int(t.get_width() / hframes)
	var fh := int(t.get_height())
	for i in range(hframes):
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("default", at)
	return sf


const FONT_DIR := "res://assets/fonts/"
const STICKER_DIR := "res://assets/ui/stickers/"


## First CJK-capable font found in res://assets/fonts/ (or null). Scans the
## folder, then a few known names, so any dropped .ttf/.otf is picked up.
static func font() -> Font:
	for p in _font_candidates():
		if ResourceLoader.exists(p):
			var r: Resource = load(p)
			if r is Font:
				return r
	return null


static func _font_candidates() -> Array:
	var out: Array = []
	var dir := DirAccess.open(FONT_DIR)
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.get_extension().to_lower() in ["ttf", "otf", "woff2", "woff", "fnt"]:
				out.append(FONT_DIR + f)
			f = dir.get_next()
		dir.list_dir_end()
	# Web exports can't reliably list res:// via DirAccess, so the scan above may
	# come back empty there. These explicit names are loaded via ResourceLoader
	# (which DOES work on web), so keep the actual shipped filename in this list.
	for n in ["main", "cjk", "font", "NotoSansCJKsc-Subset", "NotoSansCJKsc-Regular", "NotoSansSC-Regular", "SourceHanSansSC-Regular"]:
		for ext in ["ttf", "otf"]:
			out.append(FONT_DIR + n + "." + ext)
	return out


## Built-in sticker texture (or null). assets/ui/stickers/<pack>/<name>.png
static func sticker(pack: String, sticker_name: String) -> Texture2D:
	return tex(STICKER_DIR + pack + "/" + sticker_name + ".png")


## Parsed sticker manifest ({} if absent). assets/ui/stickers/manifest.json
static func sticker_manifest() -> Dictionary:
	var p := STICKER_DIR + "manifest.json"
	if not FileAccess.file_exists(p):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}
