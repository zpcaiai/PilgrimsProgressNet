import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

export type ParticleKind = 'embers' | 'dust' | 'fireflies' | 'petals' | 'mist' | 'motes' | 'snow'

const ADDITIVE: ParticleKind[] = ['embers', 'fireflies']

/** A drifting particle field — embers rise, petals fall, fireflies wander, etc. */
export function Particles({
  kind = 'motes', count = 120, color = '#ffd9a0', size = 0.18,
  bounds = [44, 20, 50], origin = [0, 6, -12], opacity = 0.7,
}: {
  kind?: ParticleKind; count?: number; color?: string; size?: number
  bounds?: [number, number, number]; origin?: [number, number, number]; opacity?: number
}) {
  const ref = useRef<THREE.Points>(null)
  const matRef = useRef<THREE.PointsMaterial>(null)
  const [hx, hy, hz] = [bounds[0] / 2, bounds[1] / 2, bounds[2] / 2]

  const { positions, velocities, phases } = useMemo(() => {
    const positions = new Float32Array(count * 3)
    const velocities = new Float32Array(count * 3)
    const phases = new Float32Array(count)
    for (let i = 0; i < count; i++) {
      positions[i * 3] = origin[0] + (Math.random() - 0.5) * bounds[0]
      positions[i * 3 + 1] = origin[1] + (Math.random() - 0.5) * bounds[1]
      positions[i * 3 + 2] = origin[2] + (Math.random() - 0.5) * bounds[2]
      phases[i] = Math.random() * Math.PI * 2
      const up = kind === 'embers' ? 1.1 + Math.random() : kind === 'dust' || kind === 'motes' ? 0.18 : 0
      const down = kind === 'petals' ? -0.7 - Math.random() * 0.5 : kind === 'snow' ? -0.5 : 0
      velocities[i * 3] = (Math.random() - 0.5) * (kind === 'mist' ? 0.7 : 0.25)
      velocities[i * 3 + 1] = up + down + (Math.random() - 0.5) * 0.05
      velocities[i * 3 + 2] = (Math.random() - 0.5) * 0.15
    }
    return { positions, velocities, phases }
  }, [count, kind, bounds[0], bounds[1], bounds[2], origin[0], origin[1], origin[2]])

  useFrame((state, dt) => {
    const pts = ref.current
    if (!pts) return
    const arr = (pts.geometry.getAttribute('position') as THREE.BufferAttribute).array as Float32Array
    const t = state.clock.elapsedTime
    const d = Math.min(dt, 0.05)
    for (let i = 0; i < count; i++) {
      arr[i * 3] += (velocities[i * 3] + Math.sin(t * 0.6 + phases[i]) * 0.12) * d
      arr[i * 3 + 1] += velocities[i * 3 + 1] * d
      arr[i * 3 + 2] += velocities[i * 3 + 2] * d
      // wrap inside the box around the origin
      if (arr[i * 3 + 1] > origin[1] + hy) arr[i * 3 + 1] = origin[1] - hy
      else if (arr[i * 3 + 1] < origin[1] - hy) arr[i * 3 + 1] = origin[1] + hy
      if (arr[i * 3] > origin[0] + hx) arr[i * 3] = origin[0] - hx
      else if (arr[i * 3] < origin[0] - hx) arr[i * 3] = origin[0] + hx
      if (arr[i * 3 + 2] > origin[2] + hz) arr[i * 3 + 2] = origin[2] - hz
      else if (arr[i * 3 + 2] < origin[2] - hz) arr[i * 3 + 2] = origin[2] + hz
    }
    pts.geometry.getAttribute('position').needsUpdate = true
    if (kind === 'fireflies' && matRef.current) matRef.current.opacity = opacity * (0.55 + 0.45 * Math.abs(Math.sin(t * 1.5)))
  })

  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        ref={matRef}
        color={color}
        size={size}
        sizeAttenuation
        transparent
        opacity={opacity}
        depthWrite={false}
        blending={ADDITIVE.includes(kind) ? THREE.AdditiveBlending : THREE.NormalBlending}
      />
    </points>
  )
}

/** A large gradient backdrop dome (ignores scene fog, so the horizon stays coloured). */
export function GradientSky({ top, bottom }: { top: string; bottom: string }) {
  const mat = useMemo(() => new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    uniforms: { uTop: { value: new THREE.Color(top) }, uBottom: { value: new THREE.Color(bottom) } },
    vertexShader: 'varying vec3 vPos; void main(){ vPos = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: 'varying vec3 vPos; uniform vec3 uTop; uniform vec3 uBottom; void main(){ float h = clamp(normalize(vPos).y*0.5+0.5,0.0,1.0); gl_FragColor = vec4(mix(uBottom,uTop,h),1.0); }',
  }), [top, bottom])
  return <mesh scale={260} renderOrder={-1}><sphereGeometry args={[1, 32, 16]} /><primitive object={mat} attach="material" /></mesh>
}

/** Soft translucent light shafts falling from above. */
export function LightShafts({ color = '#fff2c8', positions = [[-4, -8], [3, -16]] as [number, number][] }) {
  return (
    <group>
      {positions.map(([x, z], i) => (
        <mesh key={i} position={[x, 9, z]} rotation={[0, 0, 0.06 * (i % 2 ? 1 : -1)]}>
          <coneGeometry args={[2.6, 18, 16, 1, true]} />
          <meshBasicMaterial color={color} transparent opacity={0.06} depthWrite={false} side={THREE.DoubleSide} blending={THREE.AdditiveBlending} />
        </mesh>
      ))}
    </group>
  )
}

// --- sky additions (P1 #7) ---------------------------------------------------
const _rand = (s: number) => {
  const x = Math.sin(s * 127.1 + 311.7) * 43758.5453
  return x - Math.floor(x)
}

let _soft: THREE.Texture | null = null
/** A shared soft radial sprite (white→transparent) used by sun glow & clouds. */
function softSprite(): THREE.Texture {
  if (_soft) return _soft
  const s = 128
  const c = document.createElement('canvas')
  c.width = c.height = s
  const ctx = c.getContext('2d')!
  const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2)
  g.addColorStop(0, 'rgba(255,255,255,1)')
  g.addColorStop(0.45, 'rgba(255,255,255,0.45)')
  g.addColorStop(1, 'rgba(255,255,255,0)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, s, s)
  const t = new THREE.CanvasTexture(c)
  t.colorSpace = THREE.SRGBColorSpace
  t.needsUpdate = true
  _soft = t
  return t
}

/** A glowing sun disc (additive sprite) high in the sky — picks up Bloom. */
export function SunDisc({ position = [10, 32, -64], color = '#fff2c0', size = 18 }:
  { position?: [number, number, number]; color?: string; size?: number }) {
  const tex = useMemo(softSprite, [])
  return (
    <group position={position}>
      <sprite scale={[size, size, 1]}>
        <spriteMaterial map={tex} color={color} transparent opacity={0.9} depthWrite={false} blending={THREE.AdditiveBlending} />
      </sprite>
      <sprite scale={[size * 0.38, size * 0.38, 1]}>
        <spriteMaterial map={tex} color={'#ffffff'} transparent opacity={1} depthWrite={false} blending={THREE.AdditiveBlending} />
      </sprite>
    </group>
  )
}

/** Drifting soft cloud billboards across the far sky. */
export function CloudBank({
  count = 8, area = [140, 60], y = 26, z = -64, color = '#ffffff', opacity = 0.5, speed = 0.6, size = [20, 9], seed = 1,
}: {
  count?: number; area?: [number, number]; y?: number; z?: number
  color?: string; opacity?: number; speed?: number; size?: [number, number]; seed?: number
}) {
  const tex = useMemo(softSprite, [])
  const ref = useRef<THREE.Group>(null)
  const half = area[0] / 2
  const data = useMemo(
    () => Array.from({ length: count }, (_, i) => ({
      x: (_rand(seed + i * 1.7) - 0.5) * area[0],
      y: y + (_rand(seed + i * 3.3) - 0.5) * area[1] * 0.25,
      z: z + (_rand(seed + i * 5.1) - 0.5) * area[1],
      s: 0.7 + _rand(seed + i * 7.9) * 0.9,
      v: 0.5 + (i % 3) * 0.28,
    })),
    [count, area[0], area[1], y, z, seed],
  )
  useFrame((_, dt) => {
    const g = ref.current
    if (!g) return
    g.children.forEach((ch, i) => {
      ch.position.x += dt * speed * (data[i]?.v ?? 1)
      if (ch.position.x > half) ch.position.x = -half
    })
  })
  return (
    <group ref={ref}>
      {data.map((d, i) => (
        <sprite key={i} position={[d.x, d.y, d.z]} scale={[size[0] * d.s, size[1] * d.s, 1]}>
          <spriteMaterial map={tex} color={color} transparent opacity={opacity} depthWrite={false} />
        </sprite>
      ))}
    </group>
  )
}
