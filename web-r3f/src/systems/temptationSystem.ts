import type { GameState, Temptation, StatKey } from '../types'
import { getTemptationById } from '../lib/content'
import { applyMutation } from './_apply'
import { getArmorResistances } from './sacredArmorSystem'

/** Begin a temptation: apply its instant pressure and mark it active. */
export function triggerTemptation(gs: GameState, tempId: string): GameState {
  const t = getTemptationById(tempId)
  if (!t || gs.activeTemptations.includes(tempId)) return gs
  const next = applyMutation(gs, { effects: t.instantEffects })
  return { ...next, activeTemptations: [...next.activeTemptations, tempId] }
}

/** Can the pilgrim resist now? Any one of: a counter-item, a flag, armour, or meeting stat thresholds. */
export function canResistTemptation(gs: GameState, t: Temptation): boolean {
  const r = t.resistedBy
  if (r.items && r.items.some((i) => gs.inventory.items.includes(i))) return true
  if (r.flags && r.flags.length > 0 && r.flags.some((f) => gs.storyFlags[f])) return true
  if (getArmorResistances(gs).includes(t.type)) return true
  if (r.stats) {
    const ok = (Object.keys(r.stats) as StatKey[]).every(
      (k) => gs.spiritualStats[k] >= (r.stats![k] ?? 0),
    )
    if (ok) return true
  }
  return false
}

/** Resolve an active temptation. `resisted` is normally computed by canResistTemptation in the UI. */
export function resolveTemptation(gs: GameState, tempId: string, resisted: boolean): GameState {
  const t = getTemptationById(tempId)
  if (!t) return gs
  const outcome = resisted ? t.onResist : t.onFail
  let next = gs
  if (outcome) next = applyMutation(next, { effects: outcome.effects, setFlags: outcome.setFlags })
  next = { ...next, activeTemptations: next.activeTemptations.filter((id) => id !== tempId) }
  if (resisted) {
    next = { ...next, endingReview: { ...next.endingReview, resistedTemptations: next.endingReview.resistedTemptations + 1 } }
  }
  return next
}

export function temptationOutcomeMessage(t: Temptation, resisted: boolean): string {
  return (resisted ? t.onResist?.messageCN : t.onFail?.messageCN) ?? ''
}
