import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'

/** A flaming dart that flies from Apollyon toward the pilgrim over `duration` seconds. */
export function FireDart({
  from = [0, 5.6, -13] as [number, number, number],
  to = [0, 1.4, 6] as [number, number, number],
  duration = 1.6,
}) {
  const ref = useRef<THREE.Group>(null)
  const born = useRef(0)
  useFrame((state) => {
    const g = ref.current
    if (!g) return
    if (born.current === 0) born.current = state.clock.elapsedTime
    const p = Math.min(1, (state.clock.elapsedTime - born.current) / duration)
    g.position.set(
      THREE.MathUtils.lerp(from[0], to[0], p),
      THREE.MathUtils.lerp(from[1], to[1], p),
      THREE.MathUtils.lerp(from[2], to[2], p),
    )
  })
  return (
    <group ref={ref} position={from}>
      <mesh><sphereGeometry args={[0.26, 12, 12]} /><meshStandardMaterial color="#ffb24a" emissive="#ff6a22" emissiveIntensity={2.6} /></mesh>
      <mesh position={[0, 0, 0.6]}><coneGeometry args={[0.16, 1.2, 8]} /><meshBasicMaterial color="#ff8a3a" transparent opacity={0.5} depthWrite={false} /></mesh>
      <pointLight intensity={4} distance={7} color="#ff7a3a" />
    </group>
  )
}
