import { create } from 'zustand'

// Bridges 3D (inside <Canvas>) interactions to DOM overlays (outside Canvas),
// and tracks which Batch-2 modal/panel is currently open.
type UiStore = {
  activeDialogueId: string | null
  activeChapelId: string | null
  activeChoiceId: string | null
  activeRepentanceId: string | null
  inventoryOpen: boolean
  toast: string | null
  openDialogue: (id: string) => void
  openChapel: (id: string) => void
  openChoice: (id: string) => void
  openRepentance: (id: string) => void
  openInventory: () => void
  showToast: (msg: string) => void
  clearToast: () => void
  close: () => void
}

export const useUiStore = create<UiStore>((set) => ({
  activeDialogueId: null,
  activeChapelId: null,
  activeChoiceId: null,
  activeRepentanceId: null,
  inventoryOpen: false,
  toast: null,
  openDialogue: (id) => set({ activeDialogueId: id, activeChapelId: null, activeChoiceId: null, activeRepentanceId: null, inventoryOpen: false }),
  openChapel: (id) => set({ activeChapelId: id, activeDialogueId: null, activeChoiceId: null, activeRepentanceId: null, inventoryOpen: false }),
  openChoice: (id) => set({ activeChoiceId: id, activeDialogueId: null, activeChapelId: null, activeRepentanceId: null, inventoryOpen: false }),
  openRepentance: (id) => set({ activeRepentanceId: id, activeDialogueId: null, activeChapelId: null, activeChoiceId: null, inventoryOpen: false }),
  openInventory: () => set({ inventoryOpen: true, activeDialogueId: null, activeChapelId: null, activeChoiceId: null, activeRepentanceId: null }),
  showToast: (msg) => set({ toast: msg }),
  clearToast: () => set({ toast: null }),
  close: () => set({ activeDialogueId: null, activeChapelId: null, activeChoiceId: null, activeRepentanceId: null, inventoryOpen: false }),
}))
