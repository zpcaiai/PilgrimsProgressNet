extends HazardZone
class_name DespairFlameZone
## Apollyon's despair flame. Stronger than the shame field: fear and despair both
## climb. Meant to push the player to dodge and pray rather than stand in it.

func setup(size: Vector3, effects: Dictionary = {}, interval: float = -1.0,
		line: String = "", flag: String = "") -> void:
	super.setup(
		size,
		effects if not effects.is_empty() else {"despair": 3, "fear": 2},
		interval if interval > 0.0 else 2.0,
		line if line != "" else "Despair licks at your heels. Do not stand in it.",
		flag)
