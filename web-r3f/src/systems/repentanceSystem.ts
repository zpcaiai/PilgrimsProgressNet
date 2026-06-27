import type { GameState, RepentanceEvent } from '../types'
import { getRepentanceById } from '../lib/content'
import { applyMutation } from './_apply'

/** Grace-first design: when pressures get high, a way back is always offered. */
export function shouldTriggerRepentance(gs: GameState): string | null {
  const s = gs.spiritualStats
  if (s.burden >= 70 && !gs.storyFlags.burden_lifted) return 'repent_burden_cross'
  if (s.worldliness >= 70) return 'repent_worldliness_general'
  if (s.despair >= 65 || s.doubt >= 70) return 'repent_doubt_castle'
  return null
}

export function getChapelRepentance(): RepentanceEvent | undefined {
  return getRepentanceById('repent_chapel_general')
}

/** Apply a confession option followed by the grace outcome; counts toward the ending review. */
export function applyRepentance(gs: GameState, eventId: string, optionId: string): GameState {
  const ev = getRepentanceById(eventId)
  if (!ev) return gs
  let next = gs
  const opt = ev.confessionOptions.find((o) => o.id === optionId)
  if (opt) next = applyMutation(next, { effects: opt.effects, setFlags: opt.setFlags })
  const g = ev.graceOutcome
  next = applyMutation(next, {
    effects: g.effects, setFlags: g.setFlags, removeFlags: g.removeFlags, addItems: g.addItems,
  })
  return { ...next, endingReview: { ...next.endingReview, repentedTimes: next.endingReview.repentedTimes + 1 } }
}
