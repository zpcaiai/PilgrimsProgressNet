import { create } from 'zustand'

// Movement intent from the on-screen joystick (read directly in the Player's
// frame loop via getState() to avoid per-move re-renders).
type InputStore = {
  moveX: number
  moveZ: number
  setMove: (x: number, z: number) => void
}

export const useInputStore = create<InputStore>((set) => ({
  moveX: 0,
  moveZ: 0,
  setMove: (moveX, moveZ) => set({ moveX, moveZ }),
}))
