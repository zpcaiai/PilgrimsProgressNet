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
		EventBus.toast("市集的音乐更响了。穿过人群时，把眼睛放回道路。")
	if p >= 80 and not _warned_80:
		_warned_80 = true
		SpiritualStateManager.apply_effects({"humility": 3})
		EventBus.toast("虚华市正在教你的心用人群衡量自己。记得你为何上路。")
