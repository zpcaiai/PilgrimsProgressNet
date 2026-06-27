import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { Html } from '@react-three/drei'
import { Collider } from './Collider'
import { surfaceDetailProps } from '../../lib/detailMaps'

type Vec3 = [number, number, number]
type Gesture = 'idle' | 'plead' | 'tugR' | 'tugL'

/**
 * A robed person built to the SAME proportions/height as the pilgrim (~2 m at
 * scale 1) — so the wife matches the protagonist exactly; `scale` < 1 yields a
 * child of identical build. `gesture` poses (and gently animates) the arms:
 *   plead — both arms open forward, the right raised, beckoning him back;
 *   tugR/tugL — one arm reaches up & inward, tugging at the mother's skirt.
 * `lean` tilts the whole figure (children lean toward their mother).
 */
function Person({
  position = [0, 0, 0] as Vec3,
  scale = 1,
  robe = '#7c3b46',
  hair = '#2c2320',
  skin = '#d8b48c',
  veil = false,
  phase = 0,
  gesture = 'idle',
  lean = 0,
}: {
  position?: Vec3
  scale?: number
  robe?: string
  hair?: string
  skin?: string
  veil?: boolean
  phase?: number
  gesture?: Gesture
  lean?: number
}) {
  const body = useRef<THREE.Group>(null)
  const armL = useRef<THREE.Group>(null)
  const armR = useRef<THREE.Group>(null)
  useFrame((s) => {
    const t = s.clock.elapsedTime + phase
    const b = body.current
    if (b) {
      b.position.y = Math.sin(t * 1.5) * 0.018
      b.rotation.z = Math.sin(t * 0.85) * 0.02
      // a yearning forward tilt while pleading
      b.rotation.x = THREE.MathUtils.lerp(b.rotation.x, gesture === 'plead' ? 0.12 : 0, 0.1)
    }
    const l = armL.current
    const r = armR.current
    if (gesture === 'plead') {
      // open-armed, the right hand lifted and beckoning toward the departing pilgrim
      r?.rotation.set(-1.25 + Math.sin(t * 2) * 0.13, 0, -0.18)
      l?.rotation.set(-0.65 + Math.sin(t * 2 + 0.6) * 0.1, 0, 0.22)
    } else if (gesture === 'tugR') {
      // child on the mother's left, tugging her skirt with its right (inner) arm
      r?.rotation.set(-0.45, 0, 1.02 + Math.sin(t * 3) * 0.14)
      l?.rotation.set(0.12, 0, -0.05)
    } else if (gesture === 'tugL') {
      // child on the mother's right, tugging with its left (inner) arm
      l?.rotation.set(-0.45, 0, -1.02 - Math.sin(t * 3) * 0.14)
      r?.rotation.set(0.12, 0, 0.05)
    } else {
      const sway = Math.sin(t * 1.6) * 0.05
      l?.rotation.set(0.12 + sway, 0, 0.05)
      r?.rotation.set(0.12 - sway, 0, -0.05)
    }
  })
  return (
    <group position={position} scale={scale} rotation={[0, 0, lean]}>
      <group ref={body}>
        {/* robe skirt (same anchors as the pilgrim) */}
        <mesh position={[0, 0.5, 0]} castShadow receiveShadow>
          <coneGeometry args={[0.5, 1.05, 16, 1, true]} />
          <meshStandardMaterial color={robe} roughness={0.95} metalness={0} side={THREE.DoubleSide} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        <mesh position={[0, 1.18, 0]} castShadow>
          <capsuleGeometry args={[0.26, 0.5, 6, 12]} />
          <meshStandardMaterial color={robe} roughness={0.92} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        <mesh position={[0, 1.0, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.28, 0.04, 8, 20]} />
          <meshStandardMaterial color="#5e4a2c" roughness={0.85} metalness={0} />
        </mesh>
        <mesh position={[0, 1.5, 0]} castShadow><boxGeometry args={[0.58, 0.17, 0.28]} /><meshStandardMaterial color={robe} roughness={0.9} /></mesh>
        <mesh position={[0, 1.62, 0]} castShadow><cylinderGeometry args={[0.08, 0.09, 0.13, 10]} /><meshStandardMaterial color={skin} roughness={0.7} /></mesh>
        <mesh position={[0, 1.82, 0]} castShadow><sphereGeometry args={[0.2, 18, 18]} /><meshStandardMaterial color={skin} roughness={0.6} /></mesh>
        {veil ? (
          <mesh position={[0, 1.9, -0.01]} scale={[1.14, 1.2, 1.16]} castShadow>
            <sphereGeometry args={[0.2, 16, 16, 0, Math.PI * 2, 0, Math.PI * 0.62]} />
            <meshStandardMaterial color={hair} roughness={0.92} side={THREE.DoubleSide} />
          </mesh>
        ) : (
          <mesh position={[0, 1.9, -0.03]} scale={[1, 0.82, 1.05]} castShadow>
            <sphereGeometry args={[0.205, 16, 16]} />
            <meshStandardMaterial color={hair} roughness={0.85} />
          </mesh>
        )}
        <mesh position={[-0.07, 1.84, 0.17]}><sphereGeometry args={[0.026, 8, 8]} /><meshStandardMaterial color="#241a14" /></mesh>
        <mesh position={[0.07, 1.84, 0.17]}><sphereGeometry args={[0.026, 8, 8]} /><meshStandardMaterial color="#241a14" /></mesh>
        {/* posable arms (rotated each frame by `gesture`), each with a hand */}
        <group ref={armL} position={[-0.33, 1.42, 0]}>
          <mesh position={[0, -0.35, 0]} castShadow><capsuleGeometry args={[0.08, 0.6, 4, 8]} /><meshStandardMaterial color={robe} roughness={0.9} /></mesh>
          <mesh position={[0, -0.72, 0]}><sphereGeometry args={[0.09, 10, 10]} /><meshStandardMaterial color={skin} roughness={0.65} /></mesh>
        </group>
        <group ref={armR} position={[0.33, 1.42, 0]}>
          <mesh position={[0, -0.35, 0]} castShadow><capsuleGeometry args={[0.08, 0.6, 4, 8]} /><meshStandardMaterial color={robe} roughness={0.9} /></mesh>
          <mesh position={[0, -0.72, 0]}><sphereGeometry args={[0.09, 10, 10]} /><meshStandardMaterial color={skin} roughness={0.65} /></mesh>
        </group>
        <mesh position={[-0.12, 0.06, 0.07]} castShadow><boxGeometry args={[0.15, 0.1, 0.3]} /><meshStandardMaterial color="#3a2c22" roughness={0.8} /></mesh>
        <mesh position={[0.12, 0.06, 0.07]} castShadow><boxGeometry args={[0.15, 0.1, 0.3]} /><meshStandardMaterial color="#3a2c22" roughness={0.8} /></mesh>
      </group>
    </group>
  )
}

/**
 * The pilgrim's family he leaves in the City of Destruction: his WIFE (same
 * height as the protagonist) reaching out to beg him back, with TWO CHILDREN at
 * her sides tugging her skirt — a clear "don't go" tableau. Wife is solid; the
 * children don't block the way.
 */
export function PilgrimFamily({ position = [0, 0, 0] as Vec3, onTalk }:
  { position?: Vec3; onTalk?: () => void }) {
  return (
    <group
      position={position}
      onClick={(e) => { e.stopPropagation(); onTalk?.() }}
      onPointerOver={() => (document.body.style.cursor = 'pointer')}
      onPointerOut={() => (document.body.style.cursor = 'default')}
    >
      <Collider circle={[position[0], position[2], 0.6]} />
      {/* wife — exactly the pilgrim's height, reaching out to plead */}
      <Person position={[0, 0, 0]} scale={1} robe="#7c3b46" hair="#2c2320" veil gesture="plead" phase={0.4} />
      {/* two children at her sides, leaning in and tugging her skirt */}
      <Person position={[-0.7, 0, 0.28]} scale={0.6} robe="#6a7a4a" hair="#3a2c20" skin="#e0bc94" gesture="tugR" lean={-0.12} phase={1.3} />
      <Person position={[0.68, 0, 0.32]} scale={0.66} robe="#3f6a86" hair="#241c16" skin="#e0bc94" gesture="tugL" lean={0.12} phase={2.2} />
      <Html center position={[0, 2.25, 0]} distanceFactor={14}>
        <div className="px-2 py-0.5 text-xs bg-black/65 rounded whitespace-nowrap pointer-events-none">妻子与孩子 · Your Family</div>
      </Html>
    </group>
  )
}
