import type { GameState, PlayerIdentityStage } from '../types'
import { hasFullArmor } from './sacredArmorSystem'

/**
 * The pilgrim's spiritual identity is derived from progress + flags + stats,
 * so it always reflects the true state of the journey (and drives the avatar's
 * visual state — robe colour, glow, armour).
 */
export function deriveIdentityStage(gs: GameState): PlayerIdentityStage {
  const f = gs.storyFlags
  const s = gs.spiritualStats
  const ch = gs.player.currentChapterId

  if (gs.chapters.completedChapterIds.includes('chapter_16') || f.entered_celestial_city) return 'glorified'
  if (ch === 'chapter_15' || f.crossing_river) return 'crossing'
  if (f.found_key_of_promise || ch === 'chapter_14' || ch === 'chapter_13') return f.found_key_of_promise ? 'hopeful' : 'doubting'
  if (s.doubt >= 60 && s.despair >= 50 && !f.found_key_of_promise) return 'doubting'
  if (f.hopeful_joined || ch === 'chapter_12') return 'hopeful'
  if (f.faithful_joined || f.refused_vanity || ch === 'chapter_10' || ch === 'chapter_11') return 'witnessing'
  if (gs.bosses.apollyonDefeated || ch === 'chapter_09') return 'tested'
  if (hasFullArmor(gs) || f.received_full_armor) return 'equipped'
  if (f.burden_lifted) return 'forgiven'
  if (f.accepted_evangelist_call) return 'burdened'
  return 'awakened'
}

/** Returns a new GameState with the player's identity stage refreshed. */
export function refreshIdentityStage(gs: GameState): GameState {
  const stage = deriveIdentityStage(gs)
  if (stage === gs.player.identityStage) return gs
  return { ...gs, player: { ...gs.player, identityStage: stage } }
}

export type IdentityVisual = {
  stage: PlayerIdentityStage
  labelCN: string
  robeColor: string
  glow: number      // emissive intensity 0..1
  hasArmor: boolean
  hasBurden: boolean
}

const VISUALS: Record<PlayerIdentityStage, Omit<IdentityVisual, 'stage'>> = {
  awakened:   { labelCN: '觉醒者',   robeColor: '#6b7280', glow: 0.0, hasArmor: false, hasBurden: true },
  burdened:   { labelCN: '负重者',   robeColor: '#78716c', glow: 0.05, hasArmor: false, hasBurden: true },
  forgiven:   { labelCN: '蒙赦者',   robeColor: '#e5e7eb', glow: 0.15, hasArmor: false, hasBurden: false },
  equipped:   { labelCN: '披甲者',   robeColor: '#cbd5e1', glow: 0.25, hasArmor: true,  hasBurden: false },
  tested:     { labelCN: '受试炼者', robeColor: '#c7d2fe', glow: 0.30, hasArmor: true,  hasBurden: false },
  witnessing: { labelCN: '作见证者', robeColor: '#fde68a', glow: 0.35, hasArmor: true,  hasBurden: false },
  doubting:   { labelCN: '受困者',   robeColor: '#94a3b8', glow: 0.10, hasArmor: true,  hasBurden: false },
  hopeful:    { labelCN: '存盼望者', robeColor: '#bae6fd', glow: 0.40, hasArmor: true,  hasBurden: false },
  crossing:   { labelCN: '渡河者',   robeColor: '#a5f3fc', glow: 0.50, hasArmor: true,  hasBurden: false },
  glorified:  { labelCN: '得荣者',   robeColor: '#fef9c3', glow: 0.85, hasArmor: true,  hasBurden: false },
}

export function visualForStage(stage: PlayerIdentityStage): IdentityVisual {
  return { stage, ...VISUALS[stage] }
}

export function getIdentityVisual(gs: GameState): IdentityVisual {
  return visualForStage(gs.player.identityStage)
}
