import type { GameState } from '../types'
import { applyMutation } from './_apply'
import { hasFullArmor } from './sacredArmorSystem'

// ---------------------------------------------------------------------------
// Batch 5 — boss encounters. Pure GameState -> GameState transforms applied via
// the store's `mutate`. The narrative/UI staging lives in the scene; these keep
// the canonical state changes in one place (flags + bosses + stat effects).
// ---------------------------------------------------------------------------

/** Christian may only stand against Apollyon once he has put on the whole armour. */
export function canFightApollyon(gs: GameState): boolean {
  return hasFullArmor(gs) || !!gs.storyFlags.received_full_armor
}

/**
 * Victory over Apollyon: the accuser is driven off by the shield of faith and
 * the sword of the Spirit. Records the boss flag and lifts accusation/fear.
 */
export function defeatApollyon(gs: GameState): GameState {
  if (gs.bosses.apollyonDefeated) return gs
  const next = applyMutation(gs, {
    effects: { courage: 14, faith: 12, accusation: -25, fear: -12, despair: -8, witness: 6 },
    setFlags: ['defeated_apollyon', 'stood_against_apollyon'],
  })
  return { ...next, bosses: { ...next.bosses, apollyonDefeated: true } }
}

/**
 * In Doubting Castle, Christian remembers the Key of Promise he had all along.
 * Grants the key + the flag the despair temptation is resisted by.
 */
export function rememberKeyOfPromise(gs: GameState): GameState {
  if (gs.storyFlags.found_key_of_promise) return gs
  return applyMutation(gs, {
    effects: { hope: 16, doubt: -14, despair: -16, faith: 6 },
    setFlags: ['found_key_of_promise'],
    addItems: ['key_of_promise'],
  })
}

/**
 * Escape Doubting Castle with the Key of Promise — overcoming Giant Despair.
 * Requires the key to have been remembered first.
 */
export function escapeDoubtingCastle(gs: GameState): GameState {
  if (gs.bosses.giantDespairDefeated) return gs
  if (!gs.storyFlags.found_key_of_promise) return gs
  const next = applyMutation(gs, {
    effects: { hope: 12, despair: -12, doubt: -10, courage: 8 },
    setFlags: ['escaped_doubting_castle'],
  })
  return { ...next, bosses: { ...next.bosses, giantDespairDefeated: true } }
}
