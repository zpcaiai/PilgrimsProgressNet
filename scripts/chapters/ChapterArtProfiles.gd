extends RefCounted
class_name ChapterArtProfiles
## Per-chapter art direction: bespoke lighting rig, atmosphere and environmental
## set-dressing for each of the 16 chapters.
##
## This is pure data. ChapterBase._apply_world_rebuild() reads a profile and
## applies it AFTER the chapter's own _build_chapter() has run, so the dressing
## is additive scenery framing the existing gameplay — vegetation, rock, mist,
## fire, light shafts, distant silhouettes — never a duplicate of hero geometry
## the chapter already places. All colliding dressing is kept off the central
## walkway (|x| >= ~8) so it can't block the player's path or triggers.
##
## Schema (every key optional; base() supplies defaults):
##   sun     { angle:Vector3(deg), color:Color, energy:float }
##   fill    { angle:Vector3(deg), color:Color, energy:float }   (shadowless)
##   ambient { color:Color, energy:float }
##   fog     { enabled, color, density, volumetric, vol_density, albedo,
##             emission:Color, emission_energy, height, aerial }
##   glow    { enabled, intensity, strength, bloom, threshold }
##   tonemap { mode:"aces"|"filmic"|"agx", exposure, white }
##   adjust  { brightness, contrast, saturation }
##   ssao:bool  ssil:bool
##   post    { painterly shader overrides: strength, saturation, tint:Vector3,
##             tint_amount, vignette_amount, grain_amount, brush }
##   dressing [ { op:..., ... } ]   (interpreted by ChapterBase._dress_one)


static func base() -> Dictionary:
	return {
		"sun": {"angle": Vector3(-50, -40, 0), "color": Color(1.0, 0.96, 0.9), "energy": 1.1},
		"fill": {"angle": Vector3(-25, 150, 0), "color": Color(0.6, 0.7, 0.85), "energy": 0.3},
		"ambient": {"color": Color(0.5, 0.5, 0.55), "energy": 0.6},
		"fog": {"enabled": true, "color": Color(0.62, 0.64, 0.67), "density": 0.012,
			"volumetric": false, "vol_density": 0.03, "albedo": Color(0.72, 0.74, 0.77),
			"emission": Color(0, 0, 0), "emission_energy": 0.0, "height": 0.0, "aerial": 0.4},
		"glow": {"enabled": true, "intensity": 0.8, "strength": 1.0, "bloom": 0.1, "threshold": 0.9},
		"tonemap": {"mode": "aces", "exposure": 1.0, "white": 1.0},
		"adjust": {"brightness": 1.0, "contrast": 1.05, "saturation": 1.08},
		"ssao": true,
		"ssil": false,
		"post": {},
		"dressing": [],
	}


static func for_chapter(chapter_id: String) -> Dictionary:
	var p := base()
	var ov := _overrides(chapter_id)
	for k in ov.keys():
		p[k] = ov[k]
	return p


static func _overrides(id: String) -> Dictionary:
	match id:
		"city_of_destruction":
			return {
				"sun": {"angle": Vector3(-14, -35, 0), "color": Color(1.0, 0.5, 0.26), "energy": 0.85},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.35, 0.4, 0.6), "energy": 0.2},
				"ambient": {"color": Color(0.4, 0.28, 0.24), "energy": 0.5},
				"fog": {"enabled": true, "color": Color(0.35, 0.21, 0.16), "density": 0.02,
					"volumetric": true, "vol_density": 0.05, "albedo": Color(0.3, 0.22, 0.2),
					"emission": Color(0.5, 0.2, 0.08), "emission_energy": 0.4, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 1.3, "strength": 1.1, "bloom": 0.3, "threshold": 0.7},
				"tonemap": {"mode": "filmic", "exposure": 1.05, "white": 1.2},
				"adjust": {"brightness": 1.0, "contrast": 1.12, "saturation": 1.05},
				"post": {"tint": Vector3(1.0, 0.86, 0.72), "tint_amount": 0.14, "vignette_amount": 0.42},
				"dressing": [
					{"op": "smoke", "pos": Vector3(-16, 2, -34), "scale": 2.2},
					{"op": "smoke", "pos": Vector3(14, 2, -42), "scale": 2.6},
					{"op": "smoke", "pos": Vector3(-22, 2, -52), "scale": 3.0},
					{"op": "fire", "pos": Vector3(-15, 0.5, -33), "scale": 1.6, "color": Color(1.0, 0.5, 0.18)},
					{"op": "fire", "pos": Vector3(15, 0.5, -41), "scale": 1.4, "color": Color(1.0, 0.55, 0.2)},
					{"op": "cliff", "pos": Vector3(-13, 0, -28), "size": Vector3(5, 7, 10), "tint": Color(0.28, 0.22, 0.2), "surface": "ash", "seed": 21},
					{"op": "cliff", "pos": Vector3(13, 0, -38), "size": Vector3(5, 9, 12), "tint": Color(0.26, 0.2, 0.19), "surface": "ash", "seed": 22},
					{"op": "shaft", "pos": Vector3(0, 9, -58), "length": 16, "radius": 4, "color": Color(1.0, 0.92, 0.7)},
				],
			}
		"slough_of_despond":
			return {
				"sun": {"angle": Vector3(-65, -30, 0), "color": Color(0.72, 0.74, 0.72), "energy": 0.55},
				"fill": {"angle": Vector3(-30, 150, 0), "color": Color(0.5, 0.55, 0.6), "energy": 0.25},
				"ambient": {"color": Color(0.44, 0.48, 0.46), "energy": 0.55},
				"fog": {"enabled": true, "color": Color(0.5, 0.54, 0.52), "density": 0.04,
					"volumetric": true, "vol_density": 0.06, "albedo": Color(0.55, 0.58, 0.56),
					"emission": Color(0, 0, 0), "emission_energy": 0.0, "aerial": 0.7},
				"glow": {"enabled": true, "intensity": 0.5, "strength": 0.9, "bloom": 0.05, "threshold": 0.95},
				"tonemap": {"mode": "agx", "exposure": 1.0, "white": 1.0},
				"adjust": {"brightness": 0.98, "contrast": 1.03, "saturation": 0.78},
				"post": {"saturation": 0.92, "tint": Vector3(0.92, 0.95, 0.97), "tint_amount": 0.12, "vignette_amount": 0.5, "strength": 0.92},
				"dressing": [
					{"op": "mist", "center": Vector3(0, 0, -18), "area": Vector2(44, 60), "height": 1.6, "color": Color(0.66, 0.7, 0.68)},
					{"op": "reeds", "center": Vector3(-13, 0, -10), "area": Vector2(8, 18), "count": 40, "tint": Color(0.4, 0.45, 0.36)},
					{"op": "reeds", "center": Vector3(13, 0, -26), "area": Vector2(8, 20), "count": 40, "tint": Color(0.38, 0.43, 0.34)},
					{"op": "scatter", "kind": "tree", "center": Vector3(-15, 0, -34), "area": Vector2(8, 24), "count": 4, "tint": Color(0.32, 0.34, 0.3), "seed": 31},
					{"op": "scatter", "kind": "tree", "center": Vector3(15, 0, -30), "area": Vector2(8, 24), "count": 4, "tint": Color(0.3, 0.33, 0.29), "seed": 32},
				],
			}
		"wicket_gate":
			return {
				"sun": {"angle": Vector3(-28, -55, 0), "color": Color(1.0, 0.9, 0.72), "energy": 1.15},
				"fill": {"angle": Vector3(-20, 120, 0), "color": Color(0.7, 0.8, 0.95), "energy": 0.3},
				"ambient": {"color": Color(0.62, 0.62, 0.6), "energy": 0.7},
				"fog": {"enabled": true, "color": Color(0.85, 0.82, 0.72), "density": 0.01, "aerial": 0.5},
				"glow": {"enabled": true, "intensity": 0.9, "strength": 1.0, "bloom": 0.15, "threshold": 0.85},
				"tonemap": {"mode": "aces", "exposure": 1.05, "white": 1.0},
				"adjust": {"brightness": 1.02, "contrast": 1.04, "saturation": 1.1},
				"post": {"tint": Vector3(1.0, 0.97, 0.88), "tint_amount": 0.1, "vignette_amount": 0.2},
				"dressing": [
					{"op": "grass", "center": Vector3(0, 0, -14), "area": Vector2(46, 60), "count": 480, "tint": Color(0.42, 0.56, 0.3)},
					{"op": "scatter", "kind": "tree", "center": Vector3(-14, 0, -16), "area": Vector2(10, 36), "count": 6, "tint": Color(0.36, 0.5, 0.26), "seed": 41},
					{"op": "scatter", "kind": "tree", "center": Vector3(14, 0, -16), "area": Vector2(10, 36), "count": 6, "tint": Color(0.38, 0.52, 0.27), "seed": 42},
					{"op": "scatter", "kind": "bush", "center": Vector3(-9, 0, -8), "area": Vector2(6, 30), "count": 6, "tint": Color(0.4, 0.52, 0.28), "seed": 43},
					{"op": "shaft", "pos": Vector3(0, 7, -50), "length": 13, "radius": 3, "color": Color(1.0, 0.93, 0.75)},
				],
			}
		"interpreter_house":
			return {
				"sun": {"angle": Vector3(-60, -40, 0), "color": Color(0.6, 0.55, 0.5), "energy": 0.25},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.4, 0.4, 0.5), "energy": 0.12},
				"ambient": {"color": Color(0.3, 0.26, 0.22), "energy": 0.4},
				"fog": {"enabled": false, "color": Color(0.2, 0.18, 0.16), "density": 0.0},
				"glow": {"enabled": true, "intensity": 1.0, "strength": 1.1, "bloom": 0.2, "threshold": 0.8},
				"tonemap": {"mode": "filmic", "exposure": 0.95, "white": 1.1},
				"adjust": {"brightness": 0.98, "contrast": 1.14, "saturation": 1.06},
				"post": {"tint": Vector3(1.0, 0.88, 0.68), "tint_amount": 0.18, "vignette_amount": 0.55, "grain_amount": 0.045},
				"dressing": [
					{"op": "lantern", "pos": Vector3(-9, 0, -8), "color": Color(1.0, 0.8, 0.45)},
					{"op": "lantern", "pos": Vector3(9, 0, -16), "color": Color(1.0, 0.82, 0.48)},
					{"op": "lantern", "pos": Vector3(-9, 0, -24), "color": Color(1.0, 0.78, 0.42)},
					{"op": "pillar", "pos": Vector3(-9, 0, -30), "height": 4.5, "tint": Color(0.5, 0.42, 0.34), "surface": "wood"},
					{"op": "pillar", "pos": Vector3(9, 0, -30), "height": 4.5, "tint": Color(0.5, 0.42, 0.34), "surface": "wood"},
				],
			}
		"hill_difficulty":
			return {
				"sun": {"angle": Vector3(-55, -25, 0), "color": Color(1.0, 0.96, 0.85), "energy": 1.3},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.65, 0.78, 0.95), "energy": 0.3},
				"ambient": {"color": Color(0.58, 0.6, 0.62), "energy": 0.7},
				"fog": {"enabled": true, "color": Color(0.7, 0.76, 0.82), "density": 0.01, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 0.9, "strength": 1.0, "bloom": 0.12, "threshold": 0.85},
				"tonemap": {"mode": "aces", "exposure": 1.0, "white": 1.0},
				"adjust": {"brightness": 1.0, "contrast": 1.06, "saturation": 1.08},
				"post": {"tint": Vector3(1.0, 0.98, 0.92), "tint_amount": 0.06, "vignette_amount": 0.26},
				"dressing": [
					{"op": "ridge", "center": Vector3(0, 0, -60), "length": 70, "height": 22, "tint": Color(0.5, 0.52, 0.55), "surface": "stone", "seed": 51},
					{"op": "cliff", "pos": Vector3(-12, 0, -30), "size": Vector3(6, 12, 14), "tint": Color(0.52, 0.5, 0.47), "surface": "stone", "seed": 52},
					{"op": "cliff", "pos": Vector3(12, 0, -36), "size": Vector3(6, 14, 16), "tint": Color(0.5, 0.48, 0.45), "surface": "stone", "seed": 53},
					{"op": "scatter", "kind": "pine", "center": Vector3(-13, 0, -14), "area": Vector2(8, 26), "count": 5, "tint": Color(0.3, 0.44, 0.26), "seed": 54},
					{"op": "scatter", "kind": "rock", "center": Vector3(11, 0, -12), "area": Vector2(7, 24), "count": 7, "tint": Color(0.5, 0.49, 0.46), "seed": 55},
					{"op": "scatter", "kind": "bush", "center": Vector3(0, 0, 8), "area": Vector2(30, 8), "count": 5, "tint": Color(0.36, 0.5, 0.28), "seed": 56},
				],
			}
		"palace_beautiful":
			return {
				"sun": {"angle": Vector3(-22, -50, 0), "color": Color(1.0, 0.8, 0.5), "energy": 1.2},
				"fill": {"angle": Vector3(-18, 130, 0), "color": Color(0.6, 0.68, 0.9), "energy": 0.3},
				"ambient": {"color": Color(0.6, 0.55, 0.5), "energy": 0.7},
				"fog": {"enabled": true, "color": Color(0.9, 0.78, 0.6), "density": 0.012, "aerial": 0.5},
				"glow": {"enabled": true, "intensity": 1.1, "strength": 1.05, "bloom": 0.2, "threshold": 0.8},
				"tonemap": {"mode": "aces", "exposure": 1.02, "white": 1.05},
				"adjust": {"brightness": 1.0, "contrast": 1.05, "saturation": 1.12},
				"post": {"tint": Vector3(1.0, 0.93, 0.78), "tint_amount": 0.1, "vignette_amount": 0.28},
				"dressing": [
					{"op": "pillar", "pos": Vector3(-9, 0, -10), "height": 5.0, "tint": Color(0.86, 0.82, 0.76), "surface": "marble"},
					{"op": "pillar", "pos": Vector3(9, 0, -10), "height": 5.0, "tint": Color(0.86, 0.82, 0.76), "surface": "marble"},
					{"op": "pillar", "pos": Vector3(-9, 0, -22), "height": 5.0, "tint": Color(0.86, 0.82, 0.76), "surface": "marble"},
					{"op": "pillar", "pos": Vector3(9, 0, -22), "height": 5.0, "tint": Color(0.86, 0.82, 0.76), "surface": "marble"},
					{"op": "castle_wall", "pos": Vector3(-13, 0, -40), "length": 24, "height": 7, "tint": Color(0.8, 0.76, 0.7), "axis": 1, "seed": 61},
					{"op": "castle_wall", "pos": Vector3(13, 0, -40), "length": 24, "height": 7, "tint": Color(0.8, 0.76, 0.7), "axis": 1, "seed": 62},
					{"op": "banner", "pos": Vector3(-8, 0, -6), "height": 5, "tint": Color(0.7, 0.2, 0.25)},
					{"op": "banner", "pos": Vector3(8, 0, -6), "height": 5, "tint": Color(0.25, 0.3, 0.7)},
				],
			}
		"valley_humiliation":
			return {
				"sun": {"angle": Vector3(-30, -20, 0), "color": Color(0.85, 0.35, 0.22), "energy": 0.55},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.3, 0.32, 0.45), "energy": 0.18},
				"ambient": {"color": Color(0.32, 0.22, 0.2), "energy": 0.45},
				"fog": {"enabled": true, "color": Color(0.3, 0.17, 0.14), "density": 0.025,
					"volumetric": true, "vol_density": 0.05, "albedo": Color(0.28, 0.2, 0.18),
					"emission": Color(0.4, 0.15, 0.06), "emission_energy": 0.35, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 1.2, "strength": 1.1, "bloom": 0.25, "threshold": 0.75},
				"tonemap": {"mode": "filmic", "exposure": 1.0, "white": 1.15},
				"adjust": {"brightness": 0.98, "contrast": 1.12, "saturation": 1.02},
				"post": {"tint": Vector3(1.0, 0.82, 0.7), "tint_amount": 0.16, "vignette_amount": 0.5},
				"dressing": [
					{"op": "cliff", "pos": Vector3(-11, 0, -20), "size": Vector3(6, 14, 40), "tint": Color(0.24, 0.18, 0.17), "surface": "ash", "seed": 71},
					{"op": "cliff", "pos": Vector3(11, 0, -20), "size": Vector3(6, 14, 40), "tint": Color(0.22, 0.17, 0.16), "surface": "ash", "seed": 72},
					{"op": "fire", "pos": Vector3(-9, 0.4, -16), "scale": 1.2, "color": Color(1.0, 0.45, 0.15)},
					{"op": "fire", "pos": Vector3(9, 0.4, -30), "scale": 1.0, "color": Color(1.0, 0.5, 0.18)},
					{"op": "smoke", "pos": Vector3(0, 1, -42), "scale": 2.4, "color": Color(0.14, 0.1, 0.1)},
					{"op": "mist", "center": Vector3(0, 0, -24), "area": Vector2(18, 44), "height": 1.4, "color": Color(0.35, 0.22, 0.2)},
				],
			}
		"valley_shadow_death":
			return {
				"sun": {"angle": Vector3(-70, -20, 0), "color": Color(0.4, 0.46, 0.62), "energy": 0.18},
				"fill": {"angle": Vector3(-15, 150, 0), "color": Color(0.3, 0.34, 0.5), "energy": 0.1},
				"ambient": {"color": Color(0.16, 0.18, 0.24), "energy": 0.35},
				"fog": {"enabled": true, "color": Color(0.1, 0.12, 0.18), "density": 0.05,
					"volumetric": true, "vol_density": 0.08, "albedo": Color(0.12, 0.14, 0.2),
					"emission": Color(0.05, 0.06, 0.12), "emission_energy": 0.2, "aerial": 0.8},
				"glow": {"enabled": true, "intensity": 0.9, "strength": 1.0, "bloom": 0.15, "threshold": 0.8},
				"tonemap": {"mode": "agx", "exposure": 0.95, "white": 1.0},
				"adjust": {"brightness": 0.95, "contrast": 1.15, "saturation": 0.85},
				"ssil": true,
				"post": {"saturation": 0.9, "tint": Vector3(0.8, 0.85, 1.0), "tint_amount": 0.16, "vignette_amount": 0.62, "strength": 0.94},
				"dressing": [
					{"op": "cliff", "pos": Vector3(-11, 0, -22), "size": Vector3(7, 16, 48), "tint": Color(0.14, 0.15, 0.18), "surface": "stone", "seed": 81},
					{"op": "cliff", "pos": Vector3(11, 0, -22), "size": Vector3(7, 16, 48), "tint": Color(0.13, 0.14, 0.17), "surface": "stone", "seed": 82},
					{"op": "fire", "pos": Vector3(-8, 0.2, -14), "scale": 0.7, "color": Color(0.5, 0.7, 1.0)},
					{"op": "fire", "pos": Vector3(8, 0.2, -30), "scale": 0.6, "color": Color(0.5, 0.7, 1.0)},
					{"op": "lantern", "pos": Vector3(-7, 0, -22), "color": Color(1.0, 0.78, 0.42), "tint": Color(0.3, 0.28, 0.24)},
					{"op": "mist", "center": Vector3(0, 0, -26), "area": Vector2(20, 50), "height": 1.8, "color": Color(0.2, 0.22, 0.3)},
					{"op": "shaft", "pos": Vector3(0, 8, -60), "length": 16, "radius": 3.5, "color": Color(0.7, 0.82, 1.0)},
				],
			}
		"vanity_fair":
			return {
				"sun": {"angle": Vector3(-45, -40, 0), "color": Color(1.0, 0.92, 0.74), "energy": 1.15},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.7, 0.72, 0.9), "energy": 0.3},
				"ambient": {"color": Color(0.6, 0.58, 0.54), "energy": 0.7},
				"fog": {"enabled": true, "color": Color(0.8, 0.76, 0.7), "density": 0.012, "aerial": 0.4},
				"glow": {"enabled": true, "intensity": 1.0, "strength": 1.05, "bloom": 0.2, "threshold": 0.8},
				"tonemap": {"mode": "aces", "exposure": 1.0, "white": 1.0},
				"adjust": {"brightness": 1.0, "contrast": 1.05, "saturation": 1.2},
				"post": {"saturation": 1.16, "tint": Vector3(1.0, 0.95, 0.85), "tint_amount": 0.08, "vignette_amount": 0.3},
				"dressing": [
					{"op": "stall", "pos": Vector3(-10, 0, -8), "cloth": Color(0.75, 0.2, 0.25)},
					{"op": "stall", "pos": Vector3(10, 0, -12), "cloth": Color(0.2, 0.35, 0.7)},
					{"op": "stall", "pos": Vector3(-10, 0, -22), "cloth": Color(0.7, 0.6, 0.2)},
					{"op": "stall", "pos": Vector3(10, 0, -26), "cloth": Color(0.4, 0.2, 0.55)},
					{"op": "banner", "pos": Vector3(-7, 0, -4), "height": 5, "tint": Color(0.8, 0.2, 0.2)},
					{"op": "banner", "pos": Vector3(7, 0, -4), "height": 5, "tint": Color(0.85, 0.7, 0.2)},
					{"op": "lantern", "pos": Vector3(-6, 0, -16), "color": Color(1.0, 0.85, 0.5)},
					{"op": "lantern", "pos": Vector3(6, 0, -20), "color": Color(1.0, 0.85, 0.5)},
				],
			}
		"doubting_castle":
			return {
				"sun": {"angle": Vector3(-58, -30, 0), "color": Color(0.58, 0.6, 0.7), "energy": 0.45},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.35, 0.4, 0.55), "energy": 0.2},
				"ambient": {"color": Color(0.3, 0.32, 0.38), "energy": 0.45},
				"fog": {"enabled": true, "color": Color(0.34, 0.36, 0.42), "density": 0.03,
					"volumetric": true, "vol_density": 0.05, "albedo": Color(0.36, 0.38, 0.44), "aerial": 0.7},
				"glow": {"enabled": true, "intensity": 0.6, "strength": 0.95, "bloom": 0.08, "threshold": 0.9},
				"tonemap": {"mode": "agx", "exposure": 0.98, "white": 1.05},
				"adjust": {"brightness": 0.96, "contrast": 1.12, "saturation": 0.9},
				"post": {"saturation": 0.94, "tint": Vector3(0.85, 0.88, 0.98), "tint_amount": 0.14, "vignette_amount": 0.55},
				"dressing": [
					{"op": "castle_wall", "pos": Vector3(-12, 0, -34), "length": 30, "height": 9, "tint": Color(0.3, 0.32, 0.36), "axis": 1, "seed": 91},
					{"op": "castle_wall", "pos": Vector3(12, 0, -34), "length": 30, "height": 9, "tint": Color(0.29, 0.31, 0.35), "axis": 1, "seed": 92},
					{"op": "castle_wall", "pos": Vector3(0, 0, -52), "length": 26, "height": 11, "tint": Color(0.28, 0.3, 0.34), "axis": 0, "seed": 93},
					{"op": "pillar", "pos": Vector3(-13, 0, -50), "height": 12, "tint": Color(0.3, 0.31, 0.35), "surface": "stone"},
					{"op": "pillar", "pos": Vector3(13, 0, -50), "height": 12, "tint": Color(0.3, 0.31, 0.35), "surface": "stone"},
					{"op": "mist", "center": Vector3(0, 0, -30), "area": Vector2(28, 50), "height": 1.6, "color": Color(0.32, 0.34, 0.4)},
				],
			}
		"delectable_mountains":
			return {
				"sun": {"angle": Vector3(-50, -35, 0), "color": Color(1.0, 0.97, 0.86), "energy": 1.35},
				"fill": {"angle": Vector3(-22, 140, 0), "color": Color(0.66, 0.8, 0.98), "energy": 0.35},
				"ambient": {"color": Color(0.6, 0.66, 0.66), "energy": 0.75},
				"fog": {"enabled": true, "color": Color(0.72, 0.82, 0.85), "density": 0.009, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 1.0, "strength": 1.0, "bloom": 0.15, "threshold": 0.85},
				"tonemap": {"mode": "aces", "exposure": 1.02, "white": 1.0},
				"adjust": {"brightness": 1.02, "contrast": 1.05, "saturation": 1.14},
				"post": {"tint": Vector3(1.0, 0.99, 0.94), "tint_amount": 0.05, "vignette_amount": 0.2},
				"dressing": [
					{"op": "ridge", "center": Vector3(0, 0, -64), "length": 80, "height": 26, "tint": Color(0.4, 0.55, 0.42), "surface": "grass", "seed": 101},
					{"op": "grass", "center": Vector3(0, 0, -16), "area": Vector2(48, 64), "count": 520, "tint": Color(0.4, 0.6, 0.3)},
					{"op": "scatter", "kind": "tree", "center": Vector3(-15, 0, -20), "area": Vector2(10, 40), "count": 7, "tint": Color(0.34, 0.52, 0.26), "seed": 102},
					{"op": "scatter", "kind": "tree", "center": Vector3(15, 0, -20), "area": Vector2(10, 40), "count": 7, "tint": Color(0.36, 0.54, 0.27), "seed": 103},
					{"op": "scatter", "kind": "sheep", "center": Vector3(-8, 0, -10), "area": Vector2(14, 24), "count": 5, "seed": 104},
					{"op": "scatter", "kind": "sheep", "center": Vector3(9, 0, -24), "area": Vector2(14, 24), "count": 4, "seed": 105},
					{"op": "shaft", "pos": Vector3(0, 9, -60), "length": 16, "radius": 3, "color": Color(1.0, 0.95, 0.78)},
				],
			}
		"enchanted_ground":
			return {
				"sun": {"angle": Vector3(-32, -50, 0), "color": Color(0.85, 0.72, 0.74), "energy": 0.7},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.6, 0.6, 0.8), "energy": 0.3},
				"ambient": {"color": Color(0.5, 0.46, 0.52), "energy": 0.65},
				"fog": {"enabled": true, "color": Color(0.7, 0.66, 0.74), "density": 0.03,
					"volumetric": true, "vol_density": 0.06, "albedo": Color(0.72, 0.68, 0.76),
					"emission": Color(0.3, 0.25, 0.32), "emission_energy": 0.2, "aerial": 0.7},
				"glow": {"enabled": true, "intensity": 1.1, "strength": 1.05, "bloom": 0.25, "threshold": 0.8},
				"tonemap": {"mode": "filmic", "exposure": 1.0, "white": 1.05},
				"adjust": {"brightness": 1.0, "contrast": 1.02, "saturation": 1.04},
				"post": {"tint": Vector3(0.98, 0.92, 1.0), "tint_amount": 0.16, "vignette_amount": 0.4, "brush": 1.4, "strength": 0.94},
				"dressing": [
					{"op": "mist", "center": Vector3(0, 0, -18), "area": Vector2(50, 64), "height": 2.0, "color": Color(0.74, 0.68, 0.78)},
					{"op": "grass", "center": Vector3(0, 0, -16), "area": Vector2(46, 60), "count": 420, "tint": Color(0.42, 0.5, 0.38)},
					{"op": "arch", "pos": Vector3(-11, 0, -16), "width": 3.5, "height": 3.5, "tint": Color(0.5, 0.46, 0.4), "surface": "wood"},
					{"op": "arch", "pos": Vector3(11, 0, -30), "width": 3.5, "height": 3.5, "tint": Color(0.5, 0.46, 0.4), "surface": "wood"},
					{"op": "scatter", "kind": "tree", "center": Vector3(-15, 0, -24), "area": Vector2(9, 40), "count": 5, "tint": Color(0.34, 0.46, 0.32), "seed": 111},
					{"op": "scatter", "kind": "tree", "center": Vector3(15, 0, -24), "area": Vector2(9, 40), "count": 5, "tint": Color(0.33, 0.45, 0.31), "seed": 112},
				],
			}
		"wilderness_road":
			return {
				"sun": {"angle": Vector3(-48, -30, 0), "color": Color(0.96, 0.92, 0.84), "energy": 1.1},
				"fill": {"angle": Vector3(-20, 150, 0), "color": Color(0.7, 0.74, 0.86), "energy": 0.3},
				"ambient": {"color": Color(0.56, 0.55, 0.52), "energy": 0.65},
				"fog": {"enabled": true, "color": Color(0.78, 0.76, 0.72), "density": 0.014, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 0.8, "strength": 1.0, "bloom": 0.1, "threshold": 0.88},
				"tonemap": {"mode": "aces", "exposure": 1.0, "white": 1.0},
				"adjust": {"brightness": 1.0, "contrast": 1.06, "saturation": 0.98},
				"post": {"tint": Vector3(1.0, 0.97, 0.9), "tint_amount": 0.08, "vignette_amount": 0.34},
				"dressing": [
					{"op": "ridge", "center": Vector3(0, 0, -62), "length": 80, "height": 18, "tint": Color(0.55, 0.5, 0.44), "surface": "dry_earth", "seed": 121},
					{"op": "scatter", "kind": "rock", "center": Vector3(-13, 0, -18), "area": Vector2(9, 40), "count": 9, "tint": Color(0.56, 0.5, 0.42), "seed": 122},
					{"op": "scatter", "kind": "rock", "center": Vector3(13, 0, -18), "area": Vector2(9, 40), "count": 9, "tint": Color(0.54, 0.49, 0.41), "seed": 123},
					{"op": "scatter", "kind": "bush", "center": Vector3(0, 0, -10), "area": Vector2(36, 40), "count": 8, "tint": Color(0.46, 0.46, 0.3), "seed": 124},
				],
			}
		"river_of_death":
			return {
				"sun": {"angle": Vector3(-40, -45, 0), "color": Color(0.72, 0.76, 0.86), "energy": 0.7},
				"fill": {"angle": Vector3(-18, 150, 0), "color": Color(0.55, 0.6, 0.8), "energy": 0.28},
				"ambient": {"color": Color(0.5, 0.54, 0.6), "energy": 0.6},
				"fog": {"enabled": true, "color": Color(0.6, 0.66, 0.74), "density": 0.02,
					"volumetric": true, "vol_density": 0.04, "albedo": Color(0.66, 0.72, 0.8),
					"emission": Color(0.3, 0.32, 0.28), "emission_energy": 0.2, "aerial": 0.7},
				"glow": {"enabled": true, "intensity": 1.3, "strength": 1.1, "bloom": 0.3, "threshold": 0.7},
				"tonemap": {"mode": "aces", "exposure": 1.05, "white": 1.15},
				"adjust": {"brightness": 1.0, "contrast": 1.05, "saturation": 1.05},
				"post": {"tint": Vector3(0.96, 0.97, 1.0), "tint_amount": 0.1, "vignette_amount": 0.4},
				"dressing": [
					{"op": "reeds", "center": Vector3(-13, 0, 4), "area": Vector2(8, 16), "count": 36, "tint": Color(0.4, 0.46, 0.38)},
					{"op": "reeds", "center": Vector3(13, 0, 4), "area": Vector2(8, 16), "count": 36, "tint": Color(0.4, 0.46, 0.38)},
					{"op": "mist", "center": Vector3(0, 0, -22), "area": Vector2(40, 50), "height": 1.6, "color": Color(0.66, 0.72, 0.78)},
					{"op": "shaft", "pos": Vector3(0, 11, -56), "length": 20, "radius": 5, "color": Color(1.0, 0.96, 0.82)},
					{"op": "shaft", "pos": Vector3(-7, 10, -54), "length": 18, "radius": 3, "color": Color(1.0, 0.95, 0.8)},
					{"op": "shaft", "pos": Vector3(7, 10, -54), "length": 18, "radius": 3, "color": Color(1.0, 0.95, 0.8)},
				],
			}
		"celestial_city":
			return {
				"sun": {"angle": Vector3(-35, -45, 0), "color": Color(1.0, 0.9, 0.6), "energy": 1.5},
				"fill": {"angle": Vector3(-18, 140, 0), "color": Color(0.8, 0.82, 0.95), "energy": 0.4},
				"ambient": {"color": Color(0.7, 0.66, 0.56), "energy": 0.85},
				"fog": {"enabled": true, "color": Color(1.0, 0.92, 0.72), "density": 0.014,
					"volumetric": true, "vol_density": 0.04, "albedo": Color(1.0, 0.94, 0.78),
					"emission": Color(0.6, 0.5, 0.3), "emission_energy": 0.5, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 1.6, "strength": 1.2, "bloom": 0.4, "threshold": 0.6},
				"tonemap": {"mode": "aces", "exposure": 1.08, "white": 1.3},
				"adjust": {"brightness": 1.04, "contrast": 1.04, "saturation": 1.16},
				"post": {"tint": Vector3(1.0, 0.95, 0.8), "tint_amount": 0.12, "vignette_amount": 0.18},
				"dressing": [
					{"op": "arch", "pos": Vector3(0, 0, -46), "width": 6, "height": 8, "tint": Color(1.0, 0.85, 0.45), "surface": "gold"},
					{"op": "pillar", "pos": Vector3(-10, 0, -36), "height": 9, "tint": Color(1.0, 0.85, 0.5), "surface": "gold"},
					{"op": "pillar", "pos": Vector3(10, 0, -36), "height": 9, "tint": Color(1.0, 0.85, 0.5), "surface": "gold"},
					{"op": "castle_wall", "pos": Vector3(-14, 0, -42), "length": 22, "height": 8, "tint": Color(1.0, 0.86, 0.5), "axis": 1, "seed": 131},
					{"op": "castle_wall", "pos": Vector3(14, 0, -42), "length": 22, "height": 8, "tint": Color(1.0, 0.86, 0.5), "axis": 1, "seed": 132},
					{"op": "shaft", "pos": Vector3(0, 13, -50), "length": 24, "radius": 6, "color": Color(1.0, 0.96, 0.78)},
					{"op": "shaft", "pos": Vector3(-8, 12, -48), "length": 22, "radius": 4, "color": Color(1.0, 0.94, 0.74)},
					{"op": "shaft", "pos": Vector3(8, 12, -48), "length": 22, "radius": 4, "color": Color(1.0, 0.94, 0.74)},
				],
			}
		"cross_and_tomb":
			return {
				"sun": {"angle": Vector3(-20, -50, 0), "color": Color(1.0, 0.85, 0.6), "energy": 1.25},
				"fill": {"angle": Vector3(-18, 130, 0), "color": Color(0.7, 0.78, 0.95), "energy": 0.32},
				"ambient": {"color": Color(0.6, 0.56, 0.5), "energy": 0.7},
				"fog": {"enabled": true, "color": Color(0.95, 0.82, 0.66), "density": 0.014,
					"volumetric": true, "vol_density": 0.035, "albedo": Color(0.96, 0.85, 0.7),
					"emission": Color(0.4, 0.32, 0.18), "emission_energy": 0.35, "aerial": 0.6},
				"glow": {"enabled": true, "intensity": 1.3, "strength": 1.1, "bloom": 0.3, "threshold": 0.7},
				"tonemap": {"mode": "aces", "exposure": 1.05, "white": 1.1},
				"adjust": {"brightness": 1.02, "contrast": 1.05, "saturation": 1.1},
				"post": {"tint": Vector3(1.0, 0.93, 0.78), "tint_amount": 0.12, "vignette_amount": 0.28},
				"dressing": [
					{"op": "grass", "center": Vector3(0, 0, -14), "area": Vector2(44, 56), "count": 420, "tint": Color(0.44, 0.56, 0.32)},
					{"op": "scatter", "kind": "tree", "center": Vector3(-14, 0, -20), "area": Vector2(9, 34), "count": 5, "tint": Color(0.36, 0.5, 0.27), "seed": 141},
					{"op": "scatter", "kind": "tree", "center": Vector3(14, 0, -20), "area": Vector2(9, 34), "count": 5, "tint": Color(0.37, 0.51, 0.28), "seed": 142},
					{"op": "shaft", "pos": Vector3(0, 10, -40), "length": 18, "radius": 4, "color": Color(1.0, 0.94, 0.76)},
				],
			}
		_:
			return {}
