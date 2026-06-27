import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

/**
 * Divine "glory" (P1 #8): radiating god-ray shafts + a pulsing emissive core that the
 * existing Bloom turns into a halo, plus a soft fill light. Purely additive & cheap —
 * meant for holy beats (Celestial City gate, Calvary cross). Drop it at a position.
 */
export function HolyLight({
  position = [0, 7, -11],
  color = '#fff0c0',
  radius = 5,
  rays = 12,
  intensity = 1,
}: {
  position?: [number, number, number]
  color?: string
  radius?: number
  rays?: number
  intensity?: number
}) {
  const ring = useRef<THREE.Group>(null)
  const core = useRef<THREE.Mesh>(null)
  const arms = useMemo(() => Array.from({ length: rays }, (_, i) => (i / rays) * Math.PI * 2), [rays])

  useFrame((s) => {
    const t = s.clock.elapsedTime
    if (ring.current) ring.current.rotation.z = t * 0.05
    const p = 0.85 + 0.15 * Math.sin(t * 1.6)
    if (core.current) {
      const m = core.current.material as THREE.MeshBasicMaterial
      m.opacity = 0.5 * p * intensity
      core.current.scale.setScalar(p)
    }
  })

  return (
    <group position={position}>
      <group ref={ring}>
        {arms.map((a, i) => (
          <group key={i} rotation={[0, 0, a]}>
            <mesh position={[0, radius * 0.95, 0]}>
              <coneGeometry args={[0.42, radius * 1.8, 6, 1, true]} />
              <meshBasicMaterial
                color={color}
                transparent
                opacity={0.05 * intensity}
                depthWrite={false}
                side={THREE.DoubleSide}
                blending={THREE.AdditiveBlending}
              />
            </mesh>
          </group>
        ))}
      </group>
      {/* bright pulsing core — Bloom blooms it into a halo */}
      <mesh ref={core}>
        <sphereGeometry args={[radius * 0.3, 24, 24]} />
        <meshBasicMaterial color={color} transparent opacity={0.5} depthWrite={false} blending={THREE.AdditiveBlending} />
      </mesh>
      <pointLight color={color} intensity={8 * intensity} distance={radius * 8} />
    </group>
  )
}
