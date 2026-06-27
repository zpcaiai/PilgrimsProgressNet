import * as THREE from 'three'
import { Effect, BlendFunction } from 'postprocessing'
import { wrapEffect } from '@react-three/postprocessing'

/**
 * Per-chapter colour grade (P0 #3) — a tiny ASC-CDL-ish grade run inside the existing
 * EffectComposer. Zero assets: warm/cool temperature, green/magenta tint, lift / gamma
 * / gain (contrast & brightness) and saturation, all as uniforms. A preset per sceneId
 * gives every chapter its own "film" look on top of the GradientSky / fog it already has.
 */
export type GradeParams = {
  temperature?: number // + warm, - cool
  tint?: number // + green, - magenta
  gain?: [number, number, number] // overall multiply (per channel)
  lift?: [number, number, number] // shadow raise (per channel)
  gamma?: [number, number, number] // contrast curve (per channel; >1 deepens)
  saturation?: number // 1 = unchanged
}

const FRAG = /* glsl */ `
uniform float cgTemp;
uniform float cgTint;
uniform vec3 cgGain;
uniform vec3 cgLift;
uniform vec3 cgGamma;
uniform float cgSat;

void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
  vec3 c = inputColor.rgb;
  // temperature / tint
  c.r *= (1.0 + cgTemp * 0.12);
  c.b *= (1.0 - cgTemp * 0.12);
  c.g *= (1.0 + cgTint * 0.06);
  // gain + lift + gamma
  c = c * cgGain + cgLift;
  c = pow(max(c, vec3(0.0)), cgGamma);
  // saturation
  float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
  c = mix(vec3(l), c, cgSat);
  outputColor = vec4(clamp(c, 0.0, 1.0), inputColor.a);
}
`

class ColorGradeEffect extends Effect {
  constructor({
    temperature = 0,
    tint = 0,
    gain = [1, 1, 1],
    lift = [0, 0, 0],
    gamma = [1, 1, 1],
    saturation = 1,
  }: GradeParams = {}) {
    super('ColorGradeEffect', FRAG, {
      blendFunction: BlendFunction.NORMAL,
      uniforms: new Map<string, THREE.Uniform>([
        ['cgTemp', new THREE.Uniform(temperature)],
        ['cgTint', new THREE.Uniform(tint)],
        ['cgGain', new THREE.Uniform(new THREE.Vector3(gain[0], gain[1], gain[2]))],
        ['cgLift', new THREE.Uniform(new THREE.Vector3(lift[0], lift[1], lift[2]))],
        ['cgGamma', new THREE.Uniform(new THREE.Vector3(gamma[0], gamma[1], gamma[2]))],
        ['cgSat', new THREE.Uniform(saturation)],
      ]),
    })
  }
}

/** R3F component — pass params via `args`: `<ColorGrade args={[gradeFor(sceneId)]} />`. */
export const ColorGrade = wrapEffect(ColorGradeEffect)

// --- per-chapter presets -----------------------------------------------------
const GRADES: Record<string, GradeParams> = {
  city_of_destruction: { temperature: 0.18, saturation: 0.88, gain: [1.02, 0.99, 0.96], gamma: [1.05, 1.05, 1.08] },
  slough_of_despond: { temperature: -0.12, saturation: 0.8, lift: [0.01, 0.02, 0.02] },
  interpreter_house_interior: { temperature: 0.22, saturation: 0.98, gain: [1.04, 1.0, 0.95] },
  calvary_hill: { temperature: 0.06, saturation: 1.05, gain: [1.03, 1.02, 1.02] },
  hill_difficulty_base: { temperature: 0.04, saturation: 0.95 },
  house_beautiful_interior: { temperature: 0.16, saturation: 1.05, gain: [1.04, 1.02, 0.98] },
  armory_hall: { temperature: -0.04, saturation: 0.98, gamma: [1.04, 1.04, 1.04] },
  valley_humiliation_floor: { temperature: -0.08, saturation: 0.85 },
  apollyon_arena: { temperature: 0.3, saturation: 1.08, gain: [1.06, 0.96, 0.9], gamma: [1.08, 1.08, 1.12] },
  valley_shadow_death: { temperature: -0.18, saturation: 0.55, gain: [0.92, 0.94, 1.0], gamma: [1.12, 1.12, 1.1], lift: [0.0, 0.0, 0.01] },
  vanity_fair: { temperature: 0.12, saturation: 1.18, gain: [1.04, 1.02, 1.0] },
  trial_of_faithful: { temperature: 0.2, saturation: 1.02, gain: [1.05, 0.98, 0.92], gamma: [1.06, 1.06, 1.08] },
  doubting_castle: { temperature: -0.14, saturation: 0.7, gain: [0.9, 0.92, 0.96], gamma: [1.12, 1.12, 1.12] },
  delectable_mountains: { temperature: 0.05, saturation: 1.15, gain: [1.04, 1.05, 1.02] },
  river_of_death: { temperature: -0.1, saturation: 0.85, gain: [0.96, 0.99, 1.04] },
  celestial_city: { temperature: 0.16, saturation: 1.1, gain: [1.08, 1.05, 0.98], lift: [0.02, 0.02, 0.0] },
}

const NEUTRAL: GradeParams = { temperature: 0.03, saturation: 1.02 }

export function gradeFor(sceneId: string): GradeParams {
  return GRADES[sceneId] ?? NEUTRAL
}
