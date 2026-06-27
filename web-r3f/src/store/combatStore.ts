import { create } from 'zustand'
import type { CombatState } from '../systems/combatSystem'

// Bridges the in-Canvas Apollyon fight to the DOM combat HUD (CombatOverlay).
// The scene registers handlers + pushes state; the overlay renders bars/buttons.
type Handlers = { onStart?: () => void; onGuard?: () => void; onStrike?: () => void }

type CombatStore = {
  active: boolean
  state: CombatState | null
  handlers: Handlers
  setActive: (a: boolean) => void
  setState: (s: CombatState | null) => void
  setHandlers: (h: Handlers) => void
}

export const useCombatStore = create<CombatStore>((set) => ({
  active: false,
  state: null,
  handlers: {},
  setActive: (active) => set({ active }),
  setState: (state) => set({ state }),
  setHandlers: (handlers) => set({ handlers }),
}))
