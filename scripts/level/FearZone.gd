extends HazardZone
class_name FearZone
## A pocket of dread in the Valley of the Shadow of Death. Fear creeps up, hope
## slips, while the player lingers. Non-lethal; prayer light pushes it back.

func setup(size: Vector3, effects: Dictionary = {}, interval: float = -1.0,
		line: String = "", flag: String = "") -> void:
	super.setup(
		size,
		effects if not effects.is_empty() else {"fear": 2, "hope": -1},
		interval if interval > 0.0 else 2.5,
		line if line != "" else "The dark presses close, but the road is still beneath you.",
		flag)
