import * as THREE from 'three'
import { QUALITY } from './quality'

/**
 * Shared, procedurally generated micro-surface detail maps (P0 #1).
 *
 * No network / no asset files: a tileable fbm value-noise is built once on the CPU
 * into a normal map (relief) and a grayscale roughness-variation map, then reused by
 * every material. Singletons — generated on first use, shared by reference.
 */

// --- tileable value-noise (fbm) ---------------------------------------------
function lattice(cells: number, seed: number): Float32Array {
  const a = new Float32Array(cells * cells)
  let s = (seed >>> 0) || 1
  for (let i = 0; i < a.length; i++) {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0
    a[i] = s / 4294967296
  }
  return a
}

const smooth = (t: number) => t * t * (3 - 2 * t)

/** Periodic (wrapping) value noise sampled to a size×size field — tiles seamlessly. */
function valueNoise(size: number, cells: number, seed: number): Float32Array {
  const lat = lattice(cells, seed)
  const out = new Float32Array(size * size)
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const fx = (x / size) * cells
      const fy = (y / size) * cells
      const ix = Math.floor(fx)
      const iy = Math.floor(fy)
      const x0 = ((ix % cells) + cells) % cells
      const y0 = ((iy % cells) + cells) % cells
      const x1 = (x0 + 1) % cells
      const y1 = (y0 + 1) % cells
      const tx = smooth(fx - ix)
      const ty = smooth(fy - iy)
      const v00 = lat[y0 * cells + x0]
      const v10 = lat[y0 * cells + x1]
      const v01 = lat[y1 * cells + x0]
      const v11 = lat[y1 * cells + x1]
      out[y * size + x] = (v00 * (1 - tx) + v10 * tx) * (1 - ty) + (v01 * (1 - tx) + v11 * tx) * ty
    }
  }
  return out
}

/** Multi-octave (fbm) tileable noise normalised to [0,1]. */
function fbm(size: number, seed: number, octaves: [number, number][]): Float32Array {
  const out = new Float32Array(size * size)
  let norm = 0
  for (const [cells, amp] of octaves) {
    const n = valueNoise(size, cells, seed + cells * 17)
    for (let i = 0; i < out.length; i++) out[i] += n[i] * amp
    norm += amp
  }
  for (let i = 0; i < out.length; i++) out[i] /= norm
  return out
}

const SIZE = 256 // power-of-two → mipmaps OK
const OCTAVES: [number, number][] = [[4, 1], [8, 0.5], [16, 0.25], [32, 0.125]]

let _normal: THREE.DataTexture | null = null
let _rough: THREE.DataTexture | null = null

function finishTexture(t: THREE.DataTexture, repeat = 3) {
  t.wrapS = t.wrapT = THREE.RepeatWrapping
  t.repeat.set(repeat, repeat)
  t.colorSpace = THREE.NoColorSpace // data, not colour — must not be sRGB-decoded
  t.minFilter = THREE.LinearMipmapLinearFilter
  t.magFilter = THREE.LinearFilter
  t.generateMipmaps = true
  t.anisotropy = 4
  t.needsUpdate = true
}

/** Shared tileable normal map derived from an fbm heightfield (soft micro-relief). */
export function detailNormalMap(): THREE.DataTexture {
  if (_normal) return _normal
  const h = fbm(SIZE, 1337, OCTAVES)
  const at = (x: number, y: number) => h[(((y % SIZE) + SIZE) % SIZE) * SIZE + (((x % SIZE) + SIZE) % SIZE)]
  const data = new Uint8Array(SIZE * SIZE * 4)
  const strength = 2.2
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const dx = (at(x + 1, y) - at(x - 1, y)) * strength
      const dy = (at(x, y + 1) - at(x, y - 1)) * strength
      const inv = 1 / Math.hypot(dx, dy, 1)
      const i = (y * SIZE + x) * 4
      data[i] = (-dx * inv * 0.5 + 0.5) * 255
      data[i + 1] = (-dy * inv * 0.5 + 0.5) * 255
      data[i + 2] = (inv * 0.5 + 0.5) * 255
      data[i + 3] = 255
    }
  }
  const t = new THREE.DataTexture(data, SIZE, SIZE)
  finishTexture(t)
  _normal = t
  return t
}

/** Shared tileable grayscale roughness/AO-ish variation map (lower frequency). */
export function detailRoughnessMap(): THREE.DataTexture {
  if (_rough) return _rough
  const h = fbm(SIZE, 7919, [[6, 1], [12, 0.5], [24, 0.25]])
  const data = new Uint8Array(SIZE * SIZE * 4)
  for (let i = 0; i < SIZE * SIZE; i++) {
    const v = Math.max(0, Math.min(255, h[i] * 255))
    data[i * 4] = data[i * 4 + 1] = data[i * 4 + 2] = v
    data[i * 4 + 3] = 255
  }
  const t = new THREE.DataTexture(data, SIZE, SIZE)
  finishTexture(t)
  _rough = t
  return t
}

/**
 * Props to spread onto a UV-mapped `<meshStandardMaterial>` for shared micro-detail.
 * Use on NatureKit props (rocks, trunks, foliage). For the ground prefer the
 * triplanar material (see lib/triplanarMaterial.ts), which avoids UV stretch.
 */
export function surfaceDetailProps(opts?: { normal?: boolean; normalScale?: number }) {
  if (!QUALITY.detail) return {}
  const withNormal = opts?.normal ?? true
  const ns = opts?.normalScale ?? 0.6
  return withNormal
    ? { normalMap: detailNormalMap(), normalScale: new THREE.Vector2(ns, ns), roughnessMap: detailRoughnessMap() }
    : { roughnessMap: detailRoughnessMap() }
}
