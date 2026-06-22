extends Node
class_name ResolveManager
## The pilgrim's resolve during a symbolic fight (0-100). Accusation and fear
## attacks drain it; prayer and Promise counters restore it. At 0 the player
## staggers and is offered a remembrance/prayer recovery -- never a hard game
## over. Separate from the global spiritual states so a boss can press hard
## without permanently wrecking the inner meters.

signal resolve_changed(value: int, max_value: int)
signal collapsed()

var resolve_max: int = 100
var resolve: int = 100


func reset() -> void:
	resolve = resolve_max
	resolve_changed.emit(resolve, resolve_max)


func damage(amount: int) -> void:
	if amount <= 0:
		return
	resolve = max(0, resolve - amount)
	resolve_changed.emit(resolve, resolve_max)
	if resolve <= 0:
		collapsed.emit()


func restore(amount: int) -> void:
	resolve = min(resolve_max, resolve + amount)
	resolve_changed.emit(resolve, resolve_max)
