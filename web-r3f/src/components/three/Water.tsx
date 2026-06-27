import { useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { MeshReflectorMaterial } from '@react-three/drei'
import * as THREE from 'three'
import { detailNormalMap } from '../../lib/detailMaps'
import { QUALITY } from '../../lib/quality'

type Vec3 = [number, number, number]
type Vec2 = [number, number]

/**
 * Reusable real-water surface (P1 #6): planar reflections + scrolling normal-map
 * ripples on desktop (drei MeshReflectorMaterial). On mobile (QUALITY.reflections
 * false) it falls back to a cheap transparent normal-mapped surface — same ripple,
 * no reflection render-target. Mirrors the technique already used by Ch15's river.
 */
export function Water({
  size = [40, 30],
  position = [0, 0.06, 0],
  color = '#26384a',
  flow = [0.012, 0.035],
  repeat = [5, 3.5],
  mirror = 0.6,
  opacity = 0.92,
  rippleScale = 0.3,
}: {
  size?: Vec2
  position?: Vec3
  color?: string
  flow?: Vec2
  repeat?: Vec2
  mirror?: number
  opacity?: number
  rippleScale?: number
}) {
  const normal = useMemo(() => {
    const t = detailNormalMap().clone()
    t.wrapS = t.wrapT = THREE.RepeatWrapping
    t.repeat.set(repeat[0], repeat[1])
    t.needsUpdate = true
    return t
  }, [repeat[0], repeat[1]])

  useFrame((_, dt) => {
    normal.offset.x += dt * flow[0]
    normal.offset.y += dt * flow[1]
  })

  const ns = new THREE.Vector2(rippleScale, rippleScale)

  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={position} receiveShadow>
      <planeGeometry args={[size[0], size[1]]} />
      {QUALITY.reflections ? (
        <MeshReflectorMaterial
          mirror={mirror}
          color={new THREE.Color(color)}
          normalMap={normal}
          normalScale={ns}
          metalness={0.3}
          roughness={0.2}
          transparent
          opacity={opacity}
          resolution={512}
          blur={[256, 72]}
          mixBlur={1.2}
          mixStrength={2.4}
          depthScale={1}
          minDepthThreshold={0.4}
          maxDepthThreshold={1.2}
        />
      ) : (
        <meshStandardMaterial
          color={new THREE.Color(color)}
          normalMap={normal}
          normalScale={ns}
          metalness={0.25}
          roughness={0.22}
          transparent
          opacity={opacity}
          envMapIntensity={0.8}
        />
      )}
    </mesh>
  )
}
