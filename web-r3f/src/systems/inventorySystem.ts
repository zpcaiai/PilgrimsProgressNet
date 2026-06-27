import type { GameState } from '../types'
import { getItemById } from '../lib/content'
import { applyMutation } from './_apply'

export function hasItem(gs: GameState, id: string): boolean {
  return gs.inventory.items.includes(id)
}

export function addItem(gs: GameState, id: string): GameState {
  if (hasItem(gs, id)) return gs
  return { ...gs, inventory: { ...gs.inventory, items: [...gs.inventory.items, id] } }
}

export function removeItem(gs: GameState, id: string): GameState {
  return { ...gs, inventory: { ...gs.inventory, items: gs.inventory.items.filter((i) => i !== id) } }
}

/** Use an item: apply its positive (and any negative) effects; consume if marked. */
export function useItem(gs: GameState, id: string): GameState {
  const item = getItemById(id)
  if (!item || !hasItem(gs, id)) return gs
  let next = gs
  if (item.effects) next = applyMutation(next, { effects: item.effects })
  if (item.negativeEffects) next = applyMutation(next, { effects: item.negativeEffects })
  if (item.consumable) next = removeItem(next, id)
  return next
}
