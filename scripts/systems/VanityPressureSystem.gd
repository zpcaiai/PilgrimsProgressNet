extends Node
class_name VanityPressureSystem
## Drives the Vanity Fair "vanity_pressure" meter. Pride and deception feed it;
## discernment relieves it. Crossing thresholds nudges the pilgrim with a warning
## rather than punishing. Added by GlbChapter for vanity_fair.

var _accum: float = 0.0
var _warned_50: bool = false
var _warned_80: bool = false


func _ready() -> void:
	GameState.set_temporary_meter("vanity_pressure", 0)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 2.0:
		return
	_accum = 0.0
	var p := GameState.get_temporary_meter("vanity_pressure")
	p += 1 + int(SpiritualStateManager.pride / 25.0) + int(SpiritualStateManager.deception / 25.0)
	p -= int(SpiritualStateManager.discernment / 30.0)
	GameState.set_temporary_meter("vanity_pressure", p)
	p = GameState.get_temporary_meter("vanity_pressure")
	if p >= 50 and not _warned_50:
		_warned_50 = true
		EventBus.toast("The fair's music swells. Keep your eyes on the road through the crowd.")
	if p >= 80 and not _warned_80:
		_warned_80 = true
		SpiritualStateManager.apply_effects({"humility": 3})
		EventBus.toast("The fair has taught your heart to measure itself by the crowd. Remember why you came.")
