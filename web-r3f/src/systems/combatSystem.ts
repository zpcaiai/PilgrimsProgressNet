// ---------------------------------------------------------------------------
// Batch 7 — a small combat model for the Apollyon fight. Volley-based: the boss
// telegraphs a fire-dart, the pilgrim raises the shield of faith to block, then
// ripostes with the sword of the Spirit. Grace-first: resolve never reaches a
// lethal zero, so the fight is about wearing the accuser down, not losing.
// ---------------------------------------------------------------------------

export type CombatPhase = 'intro' | 'telegraph' | 'riposte' | 'won'

export type CombatState = {
  bossHp: number
  resolve: number
  guard: boolean
  phase: CombatPhase
  volley: number
  lastBlocked: boolean
}

export const COMBAT_INIT: CombatState = {
  bossHp: 100, resolve: 100, guard: false, phase: 'intro', volley: 0, lastBlocked: false,
}

/** Boss gets fiercer as its health falls (3 tiers). */
export const tierOf = (hp: number) => (hp > 66 ? 1 : hp > 33 ? 2 : 3)
export const dartDamage = (tier: number) => (tier === 1 ? 18 : tier === 2 ? 24 : 30)
export const telegraphMs = (tier: number) => (tier === 1 ? 1800 : tier === 2 ? 1500 : 1200)
export const RIPOSTE_MS = 1800
/** A guarded volley sets up a stronger riposte. */
export const strikeDamage = (blocked: boolean) => (blocked ? 30 : 20)
/** Resolve floors here — the pilgrim staggers but is never struck down. */
export const RESOLVE_FLOOR = 8
