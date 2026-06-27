import { GradientSky, LightShafts, Particles, SunDisc, CloudBank, type ParticleKind } from './Atmosphere'
import { WaysideCross } from './WaysideCross'

type Layer = {
  kind: ParticleKind; count?: number; color?: string; size?: number
  bounds?: [number, number, number]; origin?: [number, number, number]; opacity?: number
}
type FxPreset = {
  sky: [string, string]
  layers: Layer[]
  shafts?: { color?: string; positions?: [number, number][] }
  light?: { pos: [number, number, number]; color: string; intensity: number; distance: number }
  /** A wayside cross placed in the chapter (Ch.1 omits it — the pilgrim's home carries the cross). */
  cross?: [number, number, number]
  /** A glowing sun disc in the sky (outdoor day chapters). */
  sun?: { pos: [number, number, number]; color?: string; size?: number }
  /** Drifting cloud billboards across the far sky. */
  clouds?: { y?: number; z?: number; count?: number; opacity?: number; color?: string; speed?: number }
}

// One tuned atmosphere per chapter — gradient sky + particle layers + the odd
// accent light / light-shaft + a recurring wayside cross. Rendered once inside
// the Canvas, so every scene gains depth, mood and the cross motif at once.
const FX: Record<string, FxPreset> = {
  city_of_destruction: { sky: ['#3a2a1e', '#100b09'], layers: [{ kind: 'dust', count: 90, color: '#7a6a52', opacity: 0.5 }], light: { pos: [0, 12, -10], color: '#b85a3a', intensity: 6, distance: 60 } },
  slough_of_despond: { sky: ['#2a2e2a', '#0b0f0d'], layers: [{ kind: 'mist', count: 70, color: '#5a6a5a', size: 0.5, origin: [0, 2, -14], opacity: 0.35 }], cross: [6, 0, 6] },
  interpreter_house_interior: { sky: ['#241c2a', '#0c0a10'], layers: [{ kind: 'motes', count: 80, color: '#ffcaa0', origin: [0, 4, -6], bounds: [22, 10, 24] }], light: { pos: [2, 5, -4], color: '#ff9a4a', intensity: 5, distance: 22 }, cross: [5, 0, 4] },
  calvary_hill: { sky: ['#3c3048', '#0e0a16'], layers: [{ kind: 'motes', count: 70, color: '#e8d2a0' }], shafts: { color: '#fff0c8', positions: [[-7, -18], [0, -12]] }, cross: [6, 0, 6] },
  hill_difficulty_base: { sky: ['#3a4030', '#10120c'], layers: [{ kind: 'dust', count: 80, color: '#9a8a6a', opacity: 0.45 }], sun: { pos: [12, 30, -60], color: '#ffe2b0', size: 16 }, clouds: { y: 24, z: -58, count: 7, opacity: 0.42 }, cross: [-6, 0, 6] },
  house_beautiful_interior: { sky: ['#2a2436', '#100c18'], layers: [{ kind: 'fireflies', count: 46, color: '#ffe6a0', origin: [0, 3, -6], bounds: [22, 8, 22] }, { kind: 'motes', count: 40, color: '#d8c6f0', opacity: 0.4 }], light: { pos: [0, 6, 0], color: '#ffd9a0', intensity: 4, distance: 24 }, cross: [6, 0, 4] },
  armory_hall: { sky: ['#202830', '#0a0e12'], layers: [{ kind: 'motes', count: 60, color: '#aab4c0', opacity: 0.5 }], cross: [-7, 0, 4] },
  valley_humiliation_floor: { sky: ['#1c2226', '#080a0c'], layers: [{ kind: 'mist', count: 60, color: '#3a4248', size: 0.45, origin: [0, 2, -16], opacity: 0.4 }], cross: [6, 0, 6] },
  apollyon_arena: { sky: ['#2c0c0a', '#0a0403'], layers: [{ kind: 'embers', count: 150, color: '#ff7a3a', origin: [0, 5, -10], bounds: [30, 16, 40] }], light: { pos: [0, 8, -8], color: '#ff4a2a', intensity: 7, distance: 40 }, cross: [-7, 0, 6] },
  valley_shadow_death: { sky: ['#070910', '#020205'], layers: [{ kind: 'mist', count: 50, color: '#12161f', size: 0.6, origin: [0, 2, -18], opacity: 0.5 }, { kind: 'fireflies', count: 18, color: '#3a5a8a', opacity: 0.5 }], cross: [5, 0, 6] },
  vanity_fair: { sky: ['#3a2a14', '#140e06'], layers: [{ kind: 'embers', count: 70, color: '#ffcf6a', origin: [0, 6, -10] }, { kind: 'petals', count: 60, color: '#e58ab0', origin: [0, 8, -10] }], light: { pos: [0, 9, -6], color: '#ffba5a', intensity: 5, distance: 34 }, cross: [7, 0, 6] },
  trial_of_faithful: { sky: ['#2a1c14', '#0e0805'], layers: [{ kind: 'embers', count: 90, color: '#ff8a4a', origin: [0, 5, -10] }], light: { pos: [0, 7, -10], color: '#ff7a3a', intensity: 6, distance: 30 }, cross: [-6, 0, 6] },
  doubting_castle: { sky: ['#0f0c12', '#040305'], layers: [{ kind: 'mist', count: 46, color: '#1a1620', size: 0.5, origin: [0, 3, -8], opacity: 0.45 }], cross: [-6, 0, 5] },
  delectable_mountains: { sky: ['#c2e2ef', '#6a9ad0'], layers: [{ kind: 'petals', count: 70, color: '#ffd6e6', origin: [0, 8, -16] }, { kind: 'motes', count: 60, color: '#fff0a0', opacity: 0.5 }], light: { pos: [8, 18, 6], color: '#fff3d6', intensity: 3, distance: 80 }, sun: { pos: [16, 34, -64], color: '#fff4d2', size: 22 }, clouds: { y: 26, z: -60, count: 10, opacity: 0.5 }, cross: [-7, 0, 6] },
  river_of_death: { sky: ['#26384a', '#0a1018'], layers: [{ kind: 'mist', count: 70, color: '#6a8aa0', size: 0.55, origin: [0, 1.6, -14], opacity: 0.4 }, { kind: 'motes', count: 40, color: '#cfe0ee', opacity: 0.4 }], cross: [-6, 0, 6] },
  celestial_city: { sky: ['#fff6d8', '#c69a52'], layers: [{ kind: 'motes', count: 90, color: '#fff6c0', opacity: 0.7 }, { kind: 'fireflies', count: 30, color: '#fff0c0' }], shafts: { color: '#fff4d0', positions: [[-3, -11], [3, -11], [0, -16]] }, light: { pos: [0, 16, -6], color: '#fff0c0', intensity: 6, distance: 60 }, sun: { pos: [0, 36, -66], color: '#ffe9b0', size: 26 }, clouds: { y: 28, z: -62, count: 9, opacity: 0.55, color: '#fff3da' }, cross: [-6, 0, 6] },
}

const DEFAULT: FxPreset = { sky: ['#1d2330', '#0a0c12'], layers: [{ kind: 'motes', count: 60, color: '#9aa4b8', opacity: 0.4 }], cross: [6, 0, 6] }

/** Renders the atmosphere layer (+ wayside cross) for the current scene (inside the Canvas). */
export function SceneFx({ sceneId }: { sceneId: string }) {
  const fx = FX[sceneId] ?? DEFAULT
  return (
    <group>
      <GradientSky top={fx.sky[0]} bottom={fx.sky[1]} />
      {fx.sun && <SunDisc position={fx.sun.pos} color={fx.sun.color} size={fx.sun.size} />}
      {fx.clouds && <CloudBank y={fx.clouds.y} z={fx.clouds.z} count={fx.clouds.count} opacity={fx.clouds.opacity} color={fx.clouds.color} speed={fx.clouds.speed} />}
      {fx.layers.map((l, i) => <Particles key={`${sceneId}-${i}`} {...l} />)}
      {fx.shafts && <LightShafts color={fx.shafts.color} positions={fx.shafts.positions} />}
      {fx.light && <pointLight position={fx.light.pos} color={fx.light.color} intensity={fx.light.intensity} distance={fx.light.distance} />}
      {fx.cross && <WaysideCross position={fx.cross} />}
    </group>
  )
}
