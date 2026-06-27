import type { GameState, SpiritualStats } from '../types'
import { applyStatDelta } from '../store/state'

/** A declarative bundle of state changes a system can apply immutably. */
export type Mutation = {
  effects?: Partial<SpiritualStats>
  setFlags?: string[]
  removeFlags?: string[]
  addItems?: string[]
  removeItems?: string[]
}

/** Apply a Mutation to a GameState, returning a new GameState (never mutates). */
export function applyMutation(gs: GameState, m: Mutation): GameState {
  const spiritualStats = m.effects ? applyStatDelta(gs.spiritualStats, m.effects) : gs.spiritualStats
  const storyFlags = { ...gs.storyFlags }
  ;(m.setFlags ?? []).forEach((f) => { storyFlags[f] = true })
  ;(m.removeFlags ?? []).forEach((f) => { delete storyFlags[f] })
  let items = [...gs.inventory.items]
  ;(m.addItems ?? []).forEach((it) => { if (!items.includes(it)) items.push(it) })
  if (m.removeItems && m.removeItems.length) {
    const drop = new Set(m.removeItems)
    items = items.filter((it) => !drop.has(it))
  }
  return { ...gs, spiritualStats, storyFlags, inventory: { ...gs.inventory, items } }
}
