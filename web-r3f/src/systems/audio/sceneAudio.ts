import { useEffect } from 'react'
import { audio, type AmbientPreset } from './AudioEngine'

// Per-chapter ambient pad — root note, stacked intervals, filter cutoff and
// waveform tuned to each scene's mood (dark/low for valleys & castle, bright/
// open for the mountains & city).
const AMBIENTS: Record<string, AmbientPreset> = {
  city_of_destruction:        { rootHz: 110.0, intervals: [0, 7, 10], cutoff: 600,  type: 'sawtooth', gain: 0.10 },
  slough_of_despond:          { rootHz: 87.3,  intervals: [0, 6, 12], cutoff: 420,  type: 'sine',     gain: 0.10 },
  interpreter_house_interior: { rootHz: 130.8, intervals: [0, 4, 7],  cutoff: 900,  type: 'triangle', gain: 0.08 },
  calvary_hill:               { rootHz: 130.8, intervals: [0, 7, 12], cutoff: 820,  type: 'sine',     gain: 0.10 },
  hill_difficulty_base:       { rootHz: 110.0, intervals: [0, 5, 7],  cutoff: 720,  type: 'triangle', gain: 0.08 },
  house_beautiful_interior:   { rootHz: 146.8, intervals: [0, 4, 7, 11], cutoff: 1150, type: 'triangle', gain: 0.09 },
  armory_hall:                { rootHz: 110.0, intervals: [0, 7, 12], cutoff: 860,  type: 'sawtooth', gain: 0.08 },
  valley_humiliation_floor:   { rootHz: 98.0,  intervals: [0, 3, 7],  cutoff: 560,  type: 'sine',     gain: 0.10 },
  apollyon_arena:             { rootHz: 73.4,  intervals: [0, 1, 6],  cutoff: 470,  type: 'sawtooth', gain: 0.12 },
  valley_shadow_death:        { rootHz: 65.4,  intervals: [0, 6, 11], cutoff: 360,  type: 'sine',     gain: 0.12 },
  vanity_fair:                { rootHz: 123.5, intervals: [0, 4, 8],  cutoff: 1250, type: 'square',   gain: 0.06 },
  trial_of_faithful:          { rootHz: 98.0,  intervals: [0, 3, 10], cutoff: 620,  type: 'sine',     gain: 0.10 },
  doubting_castle:            { rootHz: 61.7,  intervals: [0, 1, 7],  cutoff: 350,  type: 'sawtooth', gain: 0.12 },
  delectable_mountains:       { rootHz: 164.8, intervals: [0, 4, 7, 12], cutoff: 1450, type: 'triangle', gain: 0.09 },
  river_of_death:             { rootHz: 110.0, intervals: [0, 5, 7],  cutoff: 700,  type: 'sine',     gain: 0.10 },
  celestial_city:             { rootHz: 196.0, intervals: [0, 4, 7, 12], cutoff: 1850, type: 'triangle', gain: 0.11 },
}

const DEFAULT: AmbientPreset = { rootHz: 110, intervals: [0, 7], cutoff: 700, type: 'sine', gain: 0.08 }

/** Switch the ambient pad whenever the scene changes. */
export function useSceneAudio(sceneId: string) {
  useEffect(() => {
    audio.startAmbient(sceneId, AMBIENTS[sceneId] ?? DEFAULT)
  }, [sceneId])
}
