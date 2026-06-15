class_name AvatarUtil
extends RefCounted
## Shared avatar helpers. Globally available via `class_name` (no autoload).
## Center-crops to a square and masks to a circle, so every avatar renders round.

static func circle_texture(img: Image) -> ImageTexture:
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var s: int = mini(w, h)
	if s <= 0:
		return null
	var ox := (w - s) / 2
	var oy := (h - s) / 2
	var out := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var r := s / 2.0
	var c := Vector2(r, r)
	for y in s:
		for x in s:
			var col := img.get_pixel(ox + x, oy + y)
			# Soft 1px edge so the circle isn't jagged.
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				col.a = 0.0
			elif d > r - 1.0:
				col.a *= clampf(r - d, 0.0, 1.0)
			out.set_pixel(x, y, col)
	return ImageTexture.create_from_image(out)


## Decode raw image bytes to a circular ImageTexture (or null on failure).
static func circle_from_buffer(body: PackedByteArray, ext: String) -> ImageTexture:
	var img := Image.new()
	var err := ERR_UNAVAILABLE
	match ext.to_lower():
		"png": err = img.load_png_from_buffer(body)
		"jpg", "jpeg": err = img.load_jpg_from_buffer(body)
		"webp": err = img.load_webp_from_buffer(body)
	if err != OK:
		return null
	return circle_texture(img)


## A fallback avatar for players who have uploaded none. Uses
## res://assets/ui/avatar_default.png if present, else generates a procedural
## circular silhouette whose colour is seeded by `seed_str`.
static func default_texture(seed_str: String = "") -> ImageTexture:
	var p := "res://assets/ui/avatar_default.png"
	if ResourceLoader.exists(p):
		var r: Resource = load(p)
		if r is Texture2D:
			return circle_texture((r as Texture2D).get_image())
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var hue := float(abs(hash(seed_str)) % 360) / 360.0
	var base := Color.from_hsv(hue, 0.45, 0.62)
	var rim := Color.from_hsv(hue, 0.5, 0.9)
	var sil := base.darkened(0.45)
	var c := Vector2(s / 2.0, s / 2.0)
	var rad := s / 2.0
	var head_c := Vector2(s / 2.0, s * 0.40)
	var head_r := s * 0.16
	var body_c := Vector2(s / 2.0, s * 1.02)
	var body_r := s * 0.36
	for y in s:
		for x in s:
			var pt := Vector2(x + 0.5, y + 0.5)
			var d := pt.distance_to(c)
			if d > rad:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > rad - 3.0:
				img.set_pixel(x, y, rim)
			elif pt.distance_to(head_c) < head_r or pt.distance_to(body_c) < body_r:
				img.set_pixel(x, y, sil)
			else:
				img.set_pixel(x, y, base.lerp(base.darkened(0.18), float(y) / s))
	return ImageTexture.create_from_image(img)
