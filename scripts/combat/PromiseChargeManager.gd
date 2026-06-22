extends Node
class_name PromiseChargeManager
## Tracks Promise charges. A perfect faith-guard banks a charge; spending one
## fires a strong counter against accusation/shame. Capped so it cannot be
## hoarded indefinitely.

signal charge_changed(value: int, max_value: int)

var max_charge: int = 3
var charge: int = 0


func reset() -> void:
	charge = 0
	charge_changed.emit(charge, max_charge)


func add(amount: int = 1) -> void:
	charge = min(max_charge, charge + amount)
	charge_changed.emit(charge, max_charge)


func spend(amount: int = 1) -> bool:
	if charge < amount:
		return false
	charge -= amount
	charge_changed.emit(charge, max_charge)
	return true
