import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { Html } from '@react-three/drei'
import { Collider } from './Collider'
import { surfaceDetailProps } from '../../lib/detailMaps'

export function NPCMarker({
  name, color, position, onTalk, solid = true,
}: {
  name: string
  color: string
  position: [number, number, number]
  onTalk?: () => void
  solid?: boolean
}) {
  const body = useRef<THREE.Group>(null)
  // de-sync idle motion per NPC so a crowd doesn't breathe in lockstep
  const phase = position[0] * 1.7 + position[2] * 0.9
  useFrame((state) => {
    const b = body.current
    if (!b) return
    const t = state.clock.elapsedTime + phase
    b.position.y = Math.sin(t * 1.5) * 0.02
    b.rotation.z = Math.sin(t * 0.9) * 0.025
  })
  return (
    <group
      position={position}
      onClick={(e) => { e.stopPropagation(); onTalk?.() }}
      onPointerOver={() => (document.body.style.cursor = 'pointer')}
      onPointerOut={() => (document.body.style.cursor = 'default')}
    >
      {/* A real robed body the pilgrim bumps into instead of walking through. */}
      {solid && <Collider circle={[position[0], position[2], 0.5]} />}
      <group ref={body}>
        <mesh position={[0, 0.45, 0]} castShadow receiveShadow>
          <coneGeometry args={[0.46, 0.95, 14, 1, true]} />
          <meshStandardMaterial color={color} roughness={0.95} side={2} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        <mesh position={[0, 1.05, 0]} castShadow>
          <capsuleGeometry args={[0.24, 0.42, 6, 10]} />
          <meshStandardMaterial color={color} roughness={0.92} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        {/* rope belt */}
        <mesh position={[0, 0.88, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.26, 0.035, 8, 18]} />
          <meshStandardMaterial color="#5e4a2c" roughness={0.85} metalness={0} />
        </mesh>
        <mesh position={[0, 1.34, 0]} castShadow>
          <boxGeometry args={[0.54, 0.16, 0.27]} />
          <meshStandardMaterial color={color} roughness={0.9} />
        </mesh>
        <mesh position={[0, 1.62, 0]} castShadow>
          <sphereGeometry args={[0.19, 16, 16]} />
          <meshStandardMaterial color="#d8c6a8" roughness={0.65} />
        </mesh>
        <mesh position={[0, 1.69, -0.03]} scale={[1, 0.8, 1.05]} castShadow>
          <sphereGeometry args={[0.195, 14, 14]} />
          <meshStandardMaterial color="#3a2c20" roughness={0.85} />
        </mesh>
        {/* eyes */}
        <mesh position={[-0.07, 1.64, 0.16]}><sphereGeometry args={[0.025, 8, 8]} /><meshStandardMaterial color="#241a14" roughness={0.5} /></mesh>
        <mesh position={[0.07, 1.64, 0.16]}><sphereGeometry args={[0.025, 8, 8]} /><meshStandardMaterial color="#241a14" roughness={0.5} /></mesh>
      </group>
      <Html center position={[0, 2.1, 0]} distanceFactor={14}>
        <div className="px-2 py-0.5 text-xs bg-black/65 rounded whitespace-nowrap pointer-events-none">{name}</div>
      </Html>
    </group>
  )
}
