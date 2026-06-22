extends RefCounted
class_name CharacterPalette
## Per-character colour palettes for the in-engine 3D humanoid bodies
## (HumanoidFigure). Keeps each member of the cast recognizable now that the
## flat painted billboards are real 3D people: the pilgrim stays in his russet
## travelling tunic, Hopeful in teal, Evangelist in pale robes, and so on.
##
## A palette is a plain Dictionary so HumanoidFigure can read it without any
## typed coupling:
##   skin   : face / hands
##   hair   : crown + back of the head
##   robe   : main garment (tunic / cloak / robe)
##   robe2  : darker garment accent (trim, lower folds)
##   accent : sash / pack / trim highlight
##   long_robe : true => floor-length robe hides the legs (standing NPCs)
##               false => knee tunic, legs visible (so a walk reads clearly)
##   is_foe : true => emissive, menacing tint
##
## Names are matched on a normalized stem (lower-case, spaces -> underscores) so
## "The Interpreter" and "the_interpreter" both resolve. Unknown names fall back
## to a palette derived from the caller-supplied tint (or a stable hash of the
## name), so even un-tabled NPCs get a coherent, distinct look.

const _TABLE := {
	# Hero — warm russet travelling tunic, leather tones, visible legs to walk.
	"pilgrim": {
		"skin": Color(0.85, 0.66, 0.50), "hair": Color(0.30, 0.20, 0.12),
		"robe": Color(0.50, 0.32, 0.18), "robe2": Color(0.36, 0.23, 0.13),
		"accent": Color(0.62, 0.47, 0.27), "long_robe": false,
	},
	# Companion — hopeful teal cloak over a tunic; he walks beside you.
	"hopeful": {
		"skin": Color(0.72, 0.53, 0.39), "hair": Color(0.14, 0.10, 0.08),
		"robe": Color(0.22, 0.52, 0.46), "robe2": Color(0.14, 0.36, 0.33),
		"accent": Color(0.84, 0.73, 0.43), "long_robe": false,
	},
	# Pale prophet robes, white hair, indigo sash.
	"evangelist": {
		"skin": Color(0.85, 0.69, 0.55), "hair": Color(0.88, 0.87, 0.84),
		"robe": Color(0.85, 0.81, 0.72), "robe2": Color(0.66, 0.62, 0.54),
		"accent": Color(0.36, 0.40, 0.64), "long_robe": true,
	},
	# Gatekeeper — deep blue robe, gold trim.
	"goodwill": {
		"skin": Color(0.82, 0.65, 0.50), "hair": Color(0.26, 0.18, 0.12),
		"robe": Color(0.26, 0.38, 0.62), "robe2": Color(0.17, 0.26, 0.46),
		"accent": Color(0.84, 0.76, 0.42), "long_robe": true,
	},
	# Rescuer — earthy olive working clothes; can stride if ever a mover.
	"help": {
		"skin": Color(0.80, 0.61, 0.45), "hair": Color(0.20, 0.15, 0.10),
		"robe": Color(0.40, 0.46, 0.28), "robe2": Color(0.28, 0.33, 0.20),
		"accent": Color(0.60, 0.49, 0.30), "long_robe": false,
	},
	# Scholar — indigo-violet robe, silver hair, gold trim.
	"the_interpreter": {
		"skin": Color(0.83, 0.66, 0.52), "hair": Color(0.76, 0.74, 0.72),
		"robe": Color(0.40, 0.32, 0.54), "robe2": Color(0.27, 0.21, 0.38),
		"accent": Color(0.84, 0.74, 0.42), "long_robe": true,
	},
	# Pastoral wool, terracotta sash.
	"the_shepherds": {
		"skin": Color(0.81, 0.63, 0.48), "hair": Color(0.40, 0.29, 0.19),
		"robe": Color(0.56, 0.50, 0.36), "robe2": Color(0.40, 0.35, 0.24),
		"accent": Color(0.74, 0.40, 0.28), "long_robe": true,
	},
	# Porter / watchman — slate blue-grey, steel trim.
	"watchful": {
		"skin": Color(0.80, 0.62, 0.47), "hair": Color(0.24, 0.19, 0.15),
		"robe": Color(0.38, 0.43, 0.52), "robe2": Color(0.26, 0.30, 0.38),
		"accent": Color(0.68, 0.70, 0.74), "long_robe": true,
	},
	# Stubborn townsman — drab brown, sour.
	"obstinate": {
		"skin": Color(0.79, 0.60, 0.45), "hair": Color(0.30, 0.24, 0.18),
		"robe": Color(0.44, 0.36, 0.30), "robe2": Color(0.31, 0.25, 0.21),
		"accent": Color(0.54, 0.34, 0.26), "long_robe": false,
	},
	# Townsman — light straw / amber.
	"pliable": {
		"skin": Color(0.84, 0.66, 0.51), "hair": Color(0.46, 0.33, 0.19),
		"robe": Color(0.66, 0.56, 0.36), "robe2": Color(0.50, 0.42, 0.26),
		"accent": Color(0.78, 0.64, 0.34), "long_robe": false,
	},
	# Home — warm domestic rose.
	"your_family": {
		"skin": Color(0.86, 0.69, 0.56), "hair": Color(0.34, 0.23, 0.16),
		"robe": Color(0.64, 0.44, 0.52), "robe2": Color(0.48, 0.31, 0.39),
		"accent": Color(0.84, 0.75, 0.56), "long_robe": true,
	},
	# Foe — the Destroyer: charcoal-crimson, embered with fiery accents.
	"apollyon": {
		"skin": Color(0.42, 0.16, 0.16), "hair": Color(0.10, 0.05, 0.07),
		"robe": Color(0.32, 0.10, 0.12), "robe2": Color(0.16, 0.05, 0.07),
		"accent": Color(0.98, 0.48, 0.18), "long_robe": false, "is_foe": true,
	},
}


## Normalize a speaker / display name to a table stem.
static func _stem(name: String) -> String:
	var s := name.strip_edges().to_lower().replace(" ", "_")
	# A couple of synonyms used around the codebase.
	if s == "shepherd":
		return "the_shepherds"
	if s == "interpreter":
		return "the_interpreter"
	return s


## Return a palette Dictionary for a character. `tint` (when not pure white)
## seeds the fallback garment colour for un-tabled NPCs / foes.
static func for_name(name: String, tint: Color = Color(1, 1, 1), is_foe: bool = false) -> Dictionary:
	var stem := _stem(name)
	if _TABLE.has(stem):
		# Copy so callers can mutate freely.
		return (_TABLE[stem] as Dictionary).duplicate()
	return _fallback(name, tint, is_foe)


## Build a coherent palette from a tint (preferred) or a stable hash of the name.
static func _fallback(name: String, tint: Color, is_foe: bool) -> Dictionary:
	var robe: Color
	if _is_white(tint):
		var h := float(abs(hash(name))) / 2147483647.0
		robe = Color.from_hsv(fposmod(h, 1.0), 0.42, 0.62)
	else:
		robe = tint
	var skins := [
		Color(0.86, 0.68, 0.53), Color(0.78, 0.59, 0.44),
		Color(0.66, 0.49, 0.36), Color(0.90, 0.74, 0.60),
	]
	var skin: Color = skins[int(abs(hash(name + "_skin"))) % skins.size()]
	if is_foe:
		return {
			"skin": robe.darkened(0.4), "hair": Color(0.10, 0.07, 0.08),
			"robe": robe.darkened(0.1), "robe2": robe.darkened(0.4),
			"accent": robe.lightened(0.3), "long_robe": false, "is_foe": true,
		}
	return {
		"skin": skin, "hair": skin.darkened(0.62),
		"robe": robe, "robe2": robe.darkened(0.28),
		"accent": robe.lightened(0.25), "long_robe": true,
	}


static func _is_white(c: Color) -> bool:
	return is_equal_approx(c.r, 1.0) and is_equal_approx(c.g, 1.0) and is_equal_approx(c.b, 1.0)
