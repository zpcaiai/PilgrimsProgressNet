import { lazy, type FC } from 'react'
import { ComingSoonScene } from './ComingSoonScene'

// Each chapter scene is code-split into its own chunk and loaded on demand
// (Game.tsx wraps the router in <Suspense>). Scenes are named exports, so we
// adapt them to the default-export shape React.lazy expects.
const lazyScene = (load: () => Promise<Record<string, unknown>>, name: string): FC =>
  lazy(() => load().then((m) => ({ default: m[name] as FC })))

const SCENES: Record<string, FC> = {
  city_of_destruction: lazyScene(() => import('./Chapter01CityOfDestruction'), 'Chapter01CityOfDestruction'),
  slough_of_despond: lazyScene(() => import('./Chapter02SloughAndGate'), 'Chapter02SloughAndGate'),
  interpreter_house_interior: lazyScene(() => import('./Chapter03InterpreterHouse'), 'Chapter03InterpreterHouse'),
  calvary_hill: lazyScene(() => import('./Chapter04CalvaryHill'), 'Chapter04CalvaryHill'),
  hill_difficulty_base: lazyScene(() => import('./Chapter05HillDifficulty'), 'Chapter05HillDifficulty'),
  house_beautiful_interior: lazyScene(() => import('./Chapter06HouseBeautiful'), 'Chapter06HouseBeautiful'),
  armory_hall: lazyScene(() => import('./Chapter07Armory'), 'Chapter07Armory'),
  valley_humiliation_floor: lazyScene(() => import('./Chapter08ValleyHumiliation'), 'Chapter08ValleyHumiliation'),
  apollyon_arena: lazyScene(() => import('./Chapter09ApollyonArena'), 'Chapter09ApollyonArena'),
  valley_shadow_death: lazyScene(() => import('./Chapter10ValleyShadowDeath'), 'Chapter10ValleyShadowDeath'),
  vanity_fair: lazyScene(() => import('./Chapter11VanityFair'), 'Chapter11VanityFair'),
  trial_of_faithful: lazyScene(() => import('./Chapter12TrialOfFaithful'), 'Chapter12TrialOfFaithful'),
  doubting_castle: lazyScene(() => import('./Chapter13DoubtingCastle'), 'Chapter13DoubtingCastle'),
  delectable_mountains: lazyScene(() => import('./Chapter14DelectableMountains'), 'Chapter14DelectableMountains'),
  river_of_death: lazyScene(() => import('./Chapter15RiverOfDeath'), 'Chapter15RiverOfDeath'),
  celestial_city: lazyScene(() => import('./Chapter16CelestialCity'), 'Chapter16CelestialCity'),
}

export function SceneRouter({ sceneId }: { sceneId: string }) {
  const Scene = SCENES[sceneId] ?? ComingSoonScene
  return <Scene />
}
