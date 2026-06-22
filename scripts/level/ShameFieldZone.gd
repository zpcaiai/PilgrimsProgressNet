extends HazardZone
class_name ShameFieldZone
## Apollyon's field of accusation. Shame mounts and hope erodes inside it; the
## answer is Promise and faith-guard, not flight.

func setup(size: Vector3, effects: Dictionary = {}, interval: float = -1.0,
		line: String = "", flag: String = "") -> void:
	super.setup(
		size,
		effects if not effects.is_empty() else {"shame": 3, "hope": -1},
		interval if interval > 0.0 else 2.0,
		line if line != "" else "Accusation hangs in the air. Remember the Cross.",
		flag)
