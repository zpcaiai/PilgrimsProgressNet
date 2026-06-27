import type { GameState, SacredArmor, TemptationType } from '../types'
import { getArmorById, SACRED_ARMOR, ARMOR_SLOT_ORDER } from '../lib/content'
import { applyMutation } from './_apply'

/** Equip a single piece of the Ephesians-6 armor; applies its stat bonus once. */
export function equipArmor(gs: GameState, armorId: string): GameState {
  const armor = getArmorById(armorId)
  if (!armor) return gs
  const already = gs.inventory.equipped[armor.slot] === armor.id
  const equipped = { ...gs.inventory.equipped, [armor.slot]: armor.id }
  let next: GameState = { ...gs, inventory: { ...gs.inventory, equipped } }
  if (!already) next = applyMutation(next, { effects: armor.statBonuses })
  return next
}

/** Grant the full set at once (the Chapter-7 armory). */
export function grantFullArmor(gs: GameState): GameState {
  let next = gs
  SACRED_ARMOR.forEach((a) => { next = equipArmor(next, a.id) })
  return applyMutation(next, { setFlags: ['received_full_armor'] })
}

export function equippedArmorPieces(gs: GameState): SacredArmor[] {
  return ARMOR_SLOT_ORDER
    .map((slot) => gs.inventory.equipped[slot])
    .filter((id): id is string => !!id)
    .map((id) => getArmorById(id))
    .filter((a): a is SacredArmor => !!a)
}

export function hasFullArmor(gs: GameState): boolean {
  return ARMOR_SLOT_ORDER.every((slot) => !!gs.inventory.equipped[slot])
}

/** All temptation types the currently-equipped armor protects against. */
export function getArmorResistances(gs: GameState): TemptationType[] {
  const set = new Set<TemptationType>()
  equippedArmorPieces(gs).forEach((a) => a.countersTemptations.forEach((t) => set.add(t)))
  return Array.from(set)
}
