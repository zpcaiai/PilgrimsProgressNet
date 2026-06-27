import type { GameState, SpiritualChoice } from '../types'
import { getChoiceById, getChoicesForScene } from '../lib/content'
import { applyMutation } from './_apply'

/** Choices visible in a scene: gating by required/blocked flags and repeatability. */
export function getAvailableChoices(gs: GameState, sceneId: string): SpiritualChoice[] {
  return getChoicesForScene(sceneId).filter((c) => {
    if (c.requiredFlags && c.requiredFlags.some((f) => !gs.storyFlags[f])) return false
    if (c.blockedByFlags && c.blockedByFlags.some((f) => gs.storyFlags[f])) return false
    if (!c.repeatable && gs.choices.some((rec) => rec.choiceId === c.id)) return false
    return true
  })
}

export type ChoiceResult = { state: GameState; consequence: string }

/** Apply a chosen option: stat deltas, flags, item add/remove, and a recorded choice. */
export function applySpiritualChoice(gs: GameState, choiceId: string, optionId: string): ChoiceResult {
  const c = getChoiceById(choiceId)
  const opt = c?.options.find((o) => o.id === optionId)
  if (!c || !opt) return { state: gs, consequence: '' }
  let next = applyMutation(gs, {
    effects: opt.effects, setFlags: opt.setFlags, addItems: opt.addItems, removeItems: opt.removeItems,
  })
  next = {
    ...next,
    choices: [
      ...next.choices,
      { id: crypto.randomUUID(), chapterId: c.chapterId, choiceId: c.id, consequence: opt.consequenceCN, timestamp: Date.now() },
    ],
  }
  return { state: next, consequence: opt.consequenceCN }
}
