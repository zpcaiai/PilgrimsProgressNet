extends RefCounted
class_name BurdenColour
## What the pilgrim's burden is actually made of — and what colour that makes it.
##
## The burden was a fixed brown box for every player, in every playthrough. It
## carried nothing of what THIS pilgrim had actually done, so the most personal
## object in the game was the most generic one, and the moment it fell was the
## same moment for everyone.
##
## It is now tinted by the dominant weight the player is carrying at the time:
##
##   deception -> violet      pride -> crimson       shame -> ochre
##   fear      -> cold blue   despair -> slate       weariness -> dun
##
## Three things use it:
##
##   1. the backpack on the pilgrim's back, updated whenever the state changes,
##      so you can SEE what you are carrying getting heavier and changing hue;
##   2. the burden that rolls into the tomb, which is therefore your burden,
##      not a burden;
##   3. the residual aura after the Cross, which fades from that colour to
##      nothing over the following chapters — grace shown as transformation
##      rather than deletion.

const TINTS := {
	"deception": Color(0.42, 0.24, 0.55),
	"pride": Color(0.58, 0.16, 0.18),
	"shame": Color(0.55, 0.40, 0.16),
	"fear": Color(0.20, 0.30, 0.52),
	"despair": Color(0.28, 0.29, 0.34),
	"weariness": Color(0.42, 0.36, 0.26),
}

const BASE := Color(0.42, 0.30, 0.18)


## The state contributing most to the burden right now, or "" when the pilgrim
## is carrying nothing in particular.
static func dominant() -> String:
	var best := ""
	var best_v := 12
	for k in TINTS.keys():
		var v := SpiritualStateManager.get_state(String(k))
		if v > best_v:
			best_v = v
			best = String(k)
	return best


## Burden colour for the current spiritual state: the base sack colour pulled
## toward whichever weight dominates, by how much of it there is.
static func current() -> Color:
	var k := dominant()
	if k == "":
		return BASE
	var amount := clampf(float(SpiritualStateManager.get_state(k)) / 100.0, 0.0, 1.0)
	return BASE.lerp(TINTS[k] as Color, clampf(amount * 1.15, 0.0, 0.85))


## Human-readable name of the dominant weight, for the moment it falls.
static func dominant_label() -> String:
	match dominant():
		"deception": return "被欺哄的"
		"pride": return "自高的"
		"shame": return "羞愧的"
		"fear": return "惧怕的"
		"despair": return "绝望的"
		"weariness": return "疲惫的"
		_: return "无名的"


## Everything the burden is made of, heaviest first — used by the ending review
## and by the tomb, so the moment names what was actually put down.
static func composition() -> Array:
	var rows: Array = []
	for k in TINTS.keys():
		var v := SpiritualStateManager.get_state(String(k))
		if v > 10:
			rows.append({"state": String(k), "value": v, "color": TINTS[k]})
	rows.sort_custom(func(a, b): return int(a["value"]) > int(b["value"]))
	return rows
