import type { GameState, CompanionState } from '../types'
import { getCompanionAbilities } from '../lib/content'
import { applyMutation } from './_apply'

export function getActiveCompanions(gs: GameState): CompanionState[] {
  return gs.companions.filter((c) => c.isActive)
}

export function hasCompanion(gs: GameState, npcId: string): boolean {
  return gs.companions.some((c) => c.npcId === npcId && c.isActive)
}

export function addCompanion(gs: GameState, npcId: string, chapterId: string): GameState {
  if (gs.companions.some((c) => c.npcId === npcId)) {
    return { ...gs, companions: gs.companions.map((c) => (c.npcId === npcId ? { ...c, isActive: true } : c)) }
  }
  const comp: CompanionState = { npcId, isActive: true, joinedChapterId: chapterId, bond: 10, storyState: 'joined' }
  return { ...gs, companions: [...gs.companions, comp] }
}

/** A companion leaves or is martyred (e.g. Faithful at Vanity Fair). */
export function leaveCompanion(gs: GameState, npcId: string, chapterId: string, storyState = 'left'): GameState {
  return {
    ...gs,
    companions: gs.companions.map((c) =>
      c.npcId === npcId ? { ...c, isActive: false, leftChapterId: chapterId, storyState } : c,
    ),
  }
}

/** Faithful's martyrdom hands the torch to Hopeful and leaves a witness token. */
export function martyrFaithfulRaiseHopeful(gs: GameState, chapterId: string): GameState {
  let next = leaveCompanion(gs, 'faithful', chapterId, 'martyred')
  next = addCompanion(next, 'hopeful', chapterId)
  return applyMutation(next, {
    effects: { witness: 15, courage: 8, hope: 8 },
    setFlags: ['faithful_martyred', 'hopeful_joined'],
    addItems: ['faithful_witness_token', 'hopeful_cross'],
  })
}

export function useCompanionAbility(gs: GameState, npcId: string, abilityId: string): GameState {
  const ability = getCompanionAbilities(npcId).find((a) => a.id === abilityId)
  if (!ability || !hasCompanion(gs, npcId)) return gs
  return applyMutation(gs, { effects: ability.effects })
}
