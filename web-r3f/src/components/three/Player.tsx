import { Suspense, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import { useGameStore } from '../../store/gameStore'
import { useInputStore } from '../../store/inputStore'
import { visualForStage } from '../../systems/identitySystem'
import { resolveCollision } from '../../systems/collision'
import { setPlayerPos, playerPos } from '../../systems/playerPos'
import { inWater, getWaterZone } from '../../systems/water'
import { surfaceDetailProps } from '../../lib/detailMaps'
import { PlayerModel } from './PlayerModel'

// Set to '/models/pilgrim.glb' to use the animated GLB pilgrim instead of the
// procedural one below (procedural is the default — it tints/glows per identity stage).
const PLAYER_MODEL_SRC: string | undefined = undefined

const keys: Record<string, boolean> = {}
if (typeof window !== 'undefined') {
  window.addEventListener('keydown', (e) => { keys[e.key.toLowerCase()] = true })
  window.addEventListener('keyup', (e) => { keys[e.key.toLowerCase()] = false })
}

const PLAYER_RADIUS = 0.5

export function Player({ start = [0, 0, 6] as [number, number, number] }) {
  const ref = useRef<THREE.Group>(null)
  const bodyRef = useRef<THREE.Group>(null)
  const armL = useRef<THREE.Group>(null)
  const armR = useRef<THREE.Group>(null)
  const legL = useRef<THREE.Group>(null)
  const legR = useRef<THREE.Group>(null)
  const burden = useGameStore((s) => s.gameState.spiritualStats.burden)
  const stage = useGameStore((s) => s.gameState.player.identityStage)
  const visual = visualForStage(stage)

  useFrame((state, dt) => {
    const g = ref.current
    if (!g) return
    const speed = 7 * (burden > 60 ? 0.7 : 1) * dt
    let dx = 0, dz = 0
    if (keys['w'] || keys['arrowup']) dz -= 1
    if (keys['s'] || keys['arrowdown']) dz += 1
    if (keys['a'] || keys['arrowleft']) dx -= 1
    if (keys['d'] || keys['arrowright']) dx += 1
    const ji = useInputStore.getState()
    dx += ji.moveX
    dz += ji.moveZ
    const len = Math.hypot(dx, dz)
    if (len > 0) {
      const nx = THREE.MathUtils.clamp(g.position.x + (dx / len) * speed, -22, 22)
      const nz = THREE.MathUtils.clamp(g.position.z + (dz / len) * speed, -38, 11)
      // Block against registered walls / props / figures (no more walking through).
      const [rx, rz] = resolveCollision(nx, nz, PLAYER_RADIUS)
      g.position.x = rx
      g.position.z = rz
      g.rotation.y = Math.atan2(dx, dz)
    }
    setPlayerPos(g.position.x, g.position.y, g.position.z)

    // --- swim / wade when over the river: the pilgrim sinks and strokes ---
    const swimming = inWater(g.position.z)
    const moving = len > 0.01
    playerPos.moving = moving // drives the optional GLB pilgrim's walk clip
    const t = state.clock.elapsedTime
    const body = bodyRef.current
    if (body) {
      const zone = getWaterZone()
      // sink deeper as the water surface (fear-driven) rises, so the body is taken
      // to the waist/chest — "没入半身". Never above the ground when on dry land.
      let sinkY = 0
      if (swimming && zone) sinkY = -THREE.MathUtils.clamp(zone.surfaceY * 0.5 + 0.15, 0.2, 1.1)
      // gentle breathing when idle; a brisker bob while walking; stroke-bob in water
      const bob = swimming ? Math.sin(t * 4) * 0.06 : (moving ? Math.sin(t * 9) * 0.03 : Math.sin(t * 1.7) * 0.016)
      body.position.y = THREE.MathUtils.lerp(body.position.y, sinkY + bob, 0.12)
      body.rotation.x = THREE.MathUtils.lerp(body.rotation.x, swimming ? 0.7 : 0, 0.1)
      body.rotation.z = THREE.MathUtils.lerp(body.rotation.z, swimming ? 0 : Math.sin(t * 1.1) * 0.02, 0.08)
    }
    const stroke = swimming ? Math.sin(t * 6) : 0
    const idleSwing = (moving ? Math.sin(t * 9) * 0.25 : Math.sin(t * 1.6) * 0.06)
    if (armL.current) armL.current.rotation.x = swimming ? -0.9 + stroke * 1.4 : THREE.MathUtils.lerp(armL.current.rotation.x, 0.12 + idleSwing, 0.15)
    if (armR.current) armR.current.rotation.x = swimming ? -0.9 - stroke * 1.4 : THREE.MathUtils.lerp(armR.current.rotation.x, 0.12 - idleSwing, 0.15)

    // --- legs: a walk cycle while moving, a flutter kick while swimming ---
    const walk = moving && !swimming ? Math.sin(t * 9) : 0
    const kick = swimming ? Math.sin(t * 6) : 0
    // legs counter-swing the same-side arm (natural gait)
    if (legL.current) legL.current.rotation.x = THREE.MathUtils.lerp(legL.current.rotation.x, swimming ? kick * 0.45 : -walk * 0.5, 0.2)
    if (legR.current) legR.current.rotation.x = THREE.MathUtils.lerp(legR.current.rotation.x, swimming ? -kick * 0.45 : walk * 0.5, 0.2)
  })

  const burdenSize = burden >= 60 ? 0.6 : burden >= 30 ? 0.45 : 0.32
  const showBurden = visual.hasBurden && burden > 20
  return (
    <group ref={ref} position={start}>
      {PLAYER_MODEL_SRC ? (
        <Suspense fallback={null}>
          <PlayerModel src={PLAYER_MODEL_SRC} />
        </Suspense>
      ) : (
      <group ref={bodyRef}>
        {/* A robed pilgrim: a flared robe skirt, torso, shoulders, neck, head and
            hair — colour + glow track the spiritual identity stage. */}
        <mesh position={[0, 0.5, 0]} castShadow receiveShadow>
          <coneGeometry args={[0.52, 1.05, 16, 1, true]} />
          <meshStandardMaterial color={visual.robeColor} emissive={visual.robeColor} emissiveIntensity={visual.glow * 0.5} roughness={0.95} metalness={0} side={THREE.DoubleSide} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        <mesh position={[0, 1.18, 0]} castShadow>
          <capsuleGeometry args={[0.27, 0.5, 6, 12]} />
          <meshStandardMaterial color={visual.robeColor} emissive={visual.robeColor} emissiveIntensity={visual.glow * 0.5} roughness={0.92} {...surfaceDetailProps({ normalScale: 0.3 })} />
        </mesh>
        {/* a rope belt at the waist */}
        <mesh position={[0, 1.0, 0]} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.29, 0.04, 8, 20]} />
          <meshStandardMaterial color="#6a5230" roughness={0.85} metalness={0} />
        </mesh>
        <mesh position={[0, 1.5, 0]} castShadow>
          <boxGeometry args={[0.62, 0.18, 0.3]} />
          <meshStandardMaterial color={visual.robeColor} roughness={0.9} />
        </mesh>
        <mesh position={[0, 1.62, 0]} castShadow>
          <cylinderGeometry args={[0.09, 0.1, 0.14, 10]} />
          <meshStandardMaterial color="#c89a6a" roughness={0.7} />
        </mesh>
        <mesh position={[0, 1.82, 0]} castShadow>
          <sphereGeometry args={[0.21, 18, 18]} />
          <meshStandardMaterial color="#c89a6a" roughness={0.65} />
        </mesh>
        {/* hair cap, pushed back so the face reads */}
        <mesh position={[0, 1.9, -0.04]} scale={[1, 0.8, 1.05]} castShadow>
          <sphereGeometry args={[0.215, 16, 16]} />
          <meshStandardMaterial color="#3a2c20" roughness={0.85} />
        </mesh>
        {/* eyes + a short beard so the face reads as a person */}
        <mesh position={[-0.08, 1.84, 0.18]}><sphereGeometry args={[0.028, 8, 8]} /><meshStandardMaterial color="#241a14" roughness={0.5} /></mesh>
        <mesh position={[0.08, 1.84, 0.18]}><sphereGeometry args={[0.028, 8, 8]} /><meshStandardMaterial color="#241a14" roughness={0.5} /></mesh>
        <mesh position={[0, 1.71, 0.15]} scale={[1, 0.7, 0.6]}><sphereGeometry args={[0.12, 10, 10]} /><meshStandardMaterial color="#4a3a2a" roughness={0.9} /></mesh>

        {/* Arms — hang at rest, and stroke when swimming the river. Each has a hand. */}
        <group ref={armL} position={[-0.34, 1.42, 0]}>
          <mesh position={[0, -0.36, 0]} castShadow>
            <capsuleGeometry args={[0.085, 0.62, 4, 8]} />
            <meshStandardMaterial color={visual.robeColor} roughness={0.9} />
          </mesh>
          <mesh position={[0, -0.74, 0]} castShadow>
            <sphereGeometry args={[0.1, 10, 10]} />
            <meshStandardMaterial color="#c89a6a" roughness={0.65} />
          </mesh>
        </group>
        <group ref={armR} position={[0.34, 1.42, 0]}>
          <mesh position={[0, -0.36, 0]} castShadow>
            <capsuleGeometry args={[0.085, 0.62, 4, 8]} />
            <meshStandardMaterial color={visual.robeColor} roughness={0.9} />
          </mesh>
          <mesh position={[0, -0.74, 0]} castShadow>
            <sphereGeometry args={[0.1, 10, 10]} />
            <meshStandardMaterial color="#c89a6a" roughness={0.65} />
          </mesh>
        </group>
        {/* legs that swing from the hip — a real walk cycle (feet peek under the hem) */}
        <group ref={legL} position={[-0.13, 0.62, 0]}>
          <mesh position={[0, -0.28, 0]} castShadow><capsuleGeometry args={[0.075, 0.4, 4, 8]} /><meshStandardMaterial color={visual.robeColor} roughness={0.92} /></mesh>
          <mesh position={[0, -0.52, 0.08]} castShadow><boxGeometry args={[0.16, 0.1, 0.32]} /><meshStandardMaterial color="#3a2c22" roughness={0.8} /></mesh>
        </group>
        <group ref={legR} position={[0.13, 0.62, 0]}>
          <mesh position={[0, -0.28, 0]} castShadow><capsuleGeometry args={[0.075, 0.4, 4, 8]} /><meshStandardMaterial color={visual.robeColor} roughness={0.92} /></mesh>
          <mesh position={[0, -0.52, 0.08]} castShadow><boxGeometry args={[0.16, 0.1, 0.32]} /><meshStandardMaterial color="#3a2c22" roughness={0.8} /></mesh>
        </group>
        {/* a pilgrim's walking staff, held at the right side */}
        <group position={[0.46, 0, 0.12]} rotation={[0.08, 0, -0.06]}>
          <mesh position={[0, 1.05, 0]} castShadow><cylinderGeometry args={[0.035, 0.045, 2.1, 7]} /><meshStandardMaterial color="#6b5236" roughness={0.9} metalness={0} /></mesh>
          <mesh position={[0, 2.12, 0]} castShadow><sphereGeometry args={[0.075, 10, 10]} /><meshStandardMaterial color="#5a4530" roughness={0.85} /></mesh>
        </group>

        {/* Sacred armour appears once equipped (breastplate band, shield, sword, helmet) */}
        {visual.hasArmor && (
          <group>
            <mesh position={[0, 1.05, 0]} castShadow>
              <cylinderGeometry args={[0.42, 0.42, 0.5, 12]} />
              <meshStandardMaterial color="#d4d4d8" metalness={0.85} roughness={0.3} />
            </mesh>
            <mesh position={[-0.5, 1.0, 0.05]} rotation={[0, 0, 0.1]} castShadow>
              <cylinderGeometry args={[0.3, 0.3, 0.08, 16]} />
              <meshStandardMaterial color="#b9941f" metalness={0.8} roughness={0.35} />
            </mesh>
            <mesh position={[0.5, 0.7, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.04, 0.04, 1.1, 8]} />
              <meshStandardMaterial color="#e5e7eb" metalness={0.9} roughness={0.2} />
            </mesh>
            <mesh position={[0, 1.95, 0]} castShadow>
              <cylinderGeometry args={[0.3, 0.3, 0.18, 16]} />
              <meshStandardMaterial color="#cbd5e1" metalness={0.85} roughness={0.3} />
            </mesh>
          </group>
        )}

        {showBurden && (
          <mesh position={[0, 1.1, -0.5]} castShadow>
            <dodecahedronGeometry args={[burdenSize, 0]} />
            <meshStandardMaterial color="#3a2b23" roughness={0.95} />
          </mesh>
        )}
      </group>
      )}
    </group>
  )
}
