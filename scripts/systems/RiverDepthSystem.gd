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
			EventBus.toast("Hopeful, beside you in the water: 'Be of good courage. I feel the bottom. Remember what carried you.'")
		else:
			EventBus.toast("The water is cold and deep, but the city has not moved. Remember what carried you before.")
