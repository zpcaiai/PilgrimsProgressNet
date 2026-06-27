import { create } from 'zustand'
import { audio } from '../systems/audio/AudioEngine'

const KEY = 'pilgrim_audio_muted'
const initialMuted = (() => { try { return localStorage.getItem(KEY) === '1' } catch { return false } })()
audio.setMuted(initialMuted)

type AudioStore = {
  muted: boolean
  toggleMute: () => void
  /** Resume the AudioContext after a user gesture (browsers block autoplay). */
  unlock: () => void
}

export const useAudioStore = create<AudioStore>((set, get) => ({
  muted: initialMuted,
  toggleMute: () => {
    const m = !get().muted
    audio.setMuted(m)
    try { localStorage.setItem(KEY, m ? '1' : '0') } catch { /* ignore */ }
    set({ muted: m })
  },
  unlock: () => audio.resume(),
}))
