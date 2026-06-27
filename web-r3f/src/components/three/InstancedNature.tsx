import { useRef, useMemo, useLayoutEffect } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { QUALITY } from '../../lib/quality'

type Vec3 = [number, number, number]
type Vec2 = [number, number]

const rand = (s: number) => {
  const x = Math.sin(s * 127.1 + 311.7) * 43758.5453
  return x - Math.floor(x)
}

/** A MeshStandardMaterial with a cheap GPU wind sway for instanced blades. */
function makeGrassMaterial(color: string) {
  const m = new THREE.MeshStandardMaterial({
    color: new THREE.Color(color),
    roughness: 1,
    metalness: 0,
    side: THREE.DoubleSide,
  })
  m.userData.uTime = new THREE.Uniform(0)
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = m.userData.uTime
    sh.uniforms.uWind = { value: 0.18 }
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float uTime;\nuniform float uWind;')
      .replace(
        '#include <begin_vertex>',
        [
          '#include <begin_vertex>',
          '{',
          '  vec4 wp = modelMatrix * instanceMatrix * vec4(transformed, 1.0);',
          '  float ph = uTime * 1.5 + wp.x * 0.35 + wp.z * 0.35;',
          '  float k = max(transformed.y, 0.0);', // only the top sways, base stays planted
          '  transformed.x += sin(ph) * uWind * k;',
          '  transformed.z += cos(ph * 0.8) * uWind * 0.5 * k;',
          '}',
        ].join('\n'),
      )
  }
  m.customProgramCacheKey = () => 'grasswind-v1'
  return m
}

/**
 * Instanced grass field (P1 #5) — hundreds–thousands of swaying blades in ONE draw
 * call. Density scales with QUALITY.vegetation (mobile thins out). Seeded layout.
 */
export function GrassField({
  count = 600,
  area = [30, 30],
  center = [0, 0, -12],
  color = '#5c7a38',
  height = 0.7,
  seed = 1,
}: {
  count?: number
  area?: Vec2
  center?: Vec3
  color?: string
  height?: number
  seed?: number
}) {
  const n = Math.max(1, Math.round(count * QUALITY.vegetation))
  const ref = useRef<THREE.InstancedMesh>(null!)
  const geo = useMemo(() => {
    const g = new THREE.ConeGeometry(0.05, height, 4, 1, true)
    g.translate(0, height / 2, 0) // base at y=0 so it sways from the ground
    return g
  }, [height])
  const mat = useMemo(() => makeGrassMaterial(color), [color])

  useLayoutEffect(() => {
    const m = ref.current
    if (!m) return
    const d = new THREE.Object3D()
    const base = new THREE.Color(color)
    for (let i = 0; i < n; i++) {
      d.position.set(
        center[0] + (rand(seed + i * 1.3) - 0.5) * area[0],
        center[1],
        center[2] + (rand(seed + i * 2.7) - 0.5) * area[1],
      )
      d.rotation.set(0, rand(i * 3.1) * Math.PI * 2, (rand(i * 5.7) - 0.5) * 0.25)
      const s = 0.7 + rand(i * 7.3) * 0.9
      d.scale.set(s, 0.8 + rand(i * 9.1) * 0.7, s)
      d.updateMatrix()
      m.setMatrixAt(i, d.matrix)
      m.setColorAt(i, base.clone().offsetHSL(0, (rand(i * 13) - 0.5) * 0.05, (rand(i * 11) - 0.5) * 0.12))
    }
    m.instanceMatrix.needsUpdate = true
    if (m.instanceColor) m.instanceColor.needsUpdate = true
    m.frustumCulled = false // spread across the area; never cull as a whole
  }, [n, area[0], area[1], center[0], center[1], center[2], color, seed])

  useFrame((s) => {
    mat.userData.uTime.value = s.clock.elapsedTime
  })

  return <instancedMesh ref={ref} args={[geo, mat, n]} castShadow receiveShadow />
}

/** Instanced flower dots — cheap colourful meadow speckle (P1 #5 companion to grass). */
export function FlowerField({
  count = 90,
  area = [26, 16],
  center = [0, 0, -22],
  colors = ['#e58ab0', '#d0a0e0', '#f0c060', '#f08a8a'],
  seed = 5,
}: {
  count?: number
  area?: Vec2
  center?: Vec3
  colors?: string[]
  seed?: number
}) {
  const n = Math.max(1, Math.round(count * QUALITY.vegetation))
  const ref = useRef<THREE.InstancedMesh>(null!)
  const geo = useMemo(() => new THREE.SphereGeometry(0.15, 8, 8), [])
  const mat = useMemo(
    () => new THREE.MeshStandardMaterial({ roughness: 0.6, metalness: 0, emissive: new THREE.Color('#1a1206'), emissiveIntensity: 0.2 }),
    [],
  )

  useLayoutEffect(() => {
    const m = ref.current
    if (!m) return
    const d = new THREE.Object3D()
    const pal = colors.map((c) => new THREE.Color(c))
    for (let i = 0; i < n; i++) {
      d.position.set(
        center[0] + (rand(seed + i * 1.7) - 0.5) * area[0],
        center[1] + 0.18 + rand(i * 4.2) * 0.1,
        center[2] + (rand(seed + i * 2.3) - 0.5) * area[1],
      )
      const s = 0.7 + rand(i * 6.1) * 0.8
      d.scale.setScalar(s)
      d.updateMatrix()
      m.setMatrixAt(i, d.matrix)
      m.setColorAt(i, pal[Math.floor(rand(i * 8.9) * pal.length) % pal.length])
    }
    m.instanceMatrix.needsUpdate = true
    if (m.instanceColor) m.instanceColor.needsUpdate = true
    m.frustumCulled = false
  }, [n, area[0], area[1], center[0], center[1], center[2], seed, colors])

  return <instancedMesh ref={ref} args={[geo, mat, n]} castShadow />
}
