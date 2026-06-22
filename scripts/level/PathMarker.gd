extends Node3D
class_name PathMarker
## A lightweight ordered waypoint (e.g. the rolling-burden track at the Cross, or
## faint path stones in the dark valley). The binder adds these to a group so a
## controller can read their positions in order. Purely positional.

@export var order: int = 0


func setup(p_order: int, group: String) -> void:
	order = p_order
	add_to_group(group)
