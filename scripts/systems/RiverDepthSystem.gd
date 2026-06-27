extends Node
class_name RiverDepthSystem
## Drives the River of Death "river_depth_pressure" meter from the pilgrim's inner
## state (fear + despair + shame + weariness, eased by faith + hope + perseverance).
## The crossing is never lethal: high pressure brings Hopeful's encouragement and a
## prompt to remember, not failure. Added by GlbChapter for river_of_death.

var _accum: float = 0.0
var _nudged: bool = false


func _ready() -> void:
	GameState.set_temporary_meter("river_depth_pressure", 0)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.5:
		return
	_accum = 0.0
	var pressure := SpiritualStateManager.fear + SpiritualStateManager.despair \
		+ SpiritualStateManager.shame + SpiritualStateManager.weariness \
		- SpiritualStateManager.faith - SpiritualStateManager.hope \
		- SpiritualStateManager.perseverance
	pressure = clampi(pressure, 0, 100)
	GameState.set_temporary_meter("river_depth_pressure", pressure)
	if pressure >= 70 and not _nudged and not DialogueManager.is_active() \
			and not GameState.has_flag("river_memory_recalled"):
		_nudged = true
		if GameState.has_companion("hopeful"):
			EventBus.toast("盼望在水中与你同行：“壮胆。我摸到底了。记得是谁托住你。”")
		else:
			EventBus.toast("水又冷又深，但城没有挪移。记得从前是谁托住你。")
