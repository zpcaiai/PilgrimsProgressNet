import { useRef, useId, useEffect } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { useGameStore } from '../../store/gameStore'
import { useUiStore } from '../../store/uiStore'
import { playerPos } from '../../systems/playerPos'
import { setObstacle, removeObstacle } from '../../systems/collision'
import { audio } from '../../systems/audio/AudioEngine'

/**
 * The creature of the River of Death — a half-submerged serpent that surfaces to
 * BAR the crossing and LUNGE at the pilgrim's heart (fear / despair). Symbolic and
 * never lethal: when faith outweighs fear (or the pilgrim presses across) it sinks
 * beneath the water and the way opens.
 */
export function RiverBeast() {
  const ref = useRef<THREE.Group>(null)
  const headRef = useRef<THREE.Group>(null)
  const ringRef = useRef<THREE.Mesh>(null)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const showToast = useUiStore((s) => s.showToast)
  const id = useId()
  const S = useRef({ cd: 2.5, receding: false, lungeT: 99, splashT: 99 })

  useEffect(() => () => removeObstacle(id), [id])

  const splash = () => { S.current.splashT = 0 }

  useFrame((state, dt) => {
    const g = ref.current
    if (!g) return
    const t = state.clock.elapsedTime
    const gs = useGameStore.getState().gameState
    const stats = gs.spiritualStats
    const crossed = !!gs.storyFlags.crossed_river
    const faith = stats.faith + stats.hope
    const fear = stats.fear + stats.doubt + stats.despair
    const px = playerPos.x
    const pz = playerPos.z

    // --- recede: faith leads, or the pilgrim has pressed across ---
    if (!S.current.receding && (crossed || faith > fear + 10 || pz <= -26)) {
      S.current.receding = true
      removeObstacle(id)
      splash()
      showToast('你定睛仰望对岸，水怪在波涛之下退去，去路敞开了。')
    }
    if (S.current.receding) {
      g.position.y = THREE.MathUtils.lerp(g.position.y, -4.5, 0.03)
      const sc = THREE.MathUtils.lerp(g.scale.x, 0.5, 0.03)
      g.scale.setScalar(sc)
    } else {
      // --- intercept: hold station just ahead of the pilgrim, toward the far shore ---
      const tx = THREE.MathUtils.clamp(px, -20, 20)
      const tz = THREE.MathUtils.clamp(pz - 3, -26, 0)
      g.position.x = THREE.MathUtils.lerp(g.position.x, tx, 0.045)
      g.position.z = THREE.MathUtils.lerp(g.position.z, tz, 0.045)
      g.position.y = 0.9 + Math.sin(t * 1.6) * 0.12
      g.rotation.y = Math.atan2(px - g.position.x, pz - g.position.z)
      setObstacle(id, { kind: 'circle', x: g.position.x, z: g.position.z, r: 1.2 })

      // attack on cooldown when close
      S.current.cd -= dt
      const dist = Math.hypot(px - g.position.x, pz - g.position.z)
      if (dist < 5 && S.current.cd <= 0) {
        S.current.cd = 3.0
        S.current.lungeT = 0
        splash()
        applyEffects({ fear: 7, despair: 4, hope: -4 })
        audio.sfx('whoosh')
        showToast('河怪缠住你，冰冷的水没过胸口——抓住信心，向前一步！')
      }
    }

    // head lunge (decaying forward jab)
    if (headRef.current) {
      S.current.lungeT += dt
      const jab = S.current.lungeT < 0.5 ? Math.sin(S.current.lungeT * Math.PI / 0.5) * 1.2 : 0
      headRef.current.position.z = 2.2 + jab
      // gentle serpentine sway
      headRef.current.position.x = Math.sin(t * 2.0) * 0.15
    }

    // expanding splash ring
    if (ringRef.current) {
      S.current.splashT += dt
      const a = S.current.splashT
      const mat = ringRef.current.material as THREE.MeshStandardMaterial
      if (a < 0.8) {
        const k = a / 0.8
        ringRef.current.visible = true
        ringRef.current.scale.setScalar(0.6 + k * 4.5)
        mat.opacity = 0.5 * (1 - k)
      } else {
        ringRef.current.visible = false
      }
    }
  })

  const scaleColor = '#0f1c1e'
  return (
    <group ref={ref} position={[0, 0.9, -6]}>
      {/* head */}
      <group ref={headRef} position={[0, 0.1, 2.2]}>
        <mesh scale={[1, 0.8, 1.7]} castShadow>
          <sphereGeometry args={[0.85, 16, 14]} />
          <meshStandardMaterial color={scaleColor} emissive="#13343a" emissiveIntensity={0.35} roughness={0.45} metalness={0.2} />
        </mesh>
        <mesh position={[0, -0.45, 0.5]}>
          <boxGeometry args={[1, 0.28, 1.5]} />
          <meshStandardMaterial color={scaleColor} roughness={0.5} />
        </mesh>
        {[-0.42, 0.42].map((x) => (
          <mesh key={x} position={[x, 0.28, 0.7]}>
            <sphereGeometry args={[0.16, 10, 10]} />
            <meshStandardMaterial color="#e9d27a" emissive="#e9d27a" emissiveIntensity={2.2} />
          </mesh>
        ))}
        {[-0.4, 0.4].map((x) => (
          <mesh key={x} position={[x, 0.5, -0.1]} rotation={[-0.9, 0, 0]}>
            <coneGeometry args={[0.13, 0.9, 6]} />
            <meshStandardMaterial color={scaleColor} roughness={0.5} />
          </mesh>
        ))}
        <Html center position={[0, 1.4, 0]} distanceFactor={26}>
          <div className="px-2 py-0.5 text-[11px] bg-black/70 rounded whitespace-nowrap pointer-events-none">死河水怪</div>
        </Html>
      </group>

      {/* coiled humps trailing behind */}
      {[0, 1, 2, 3, 4].map((i) => {
        const r = 0.95 * Math.pow(0.82, i)
        return (
          <mesh key={i} position={[0, -0.05 - i * 0.04, 0.9 - i * 1.25]} castShadow>
            <sphereGeometry args={[r, 14, 12]} />
            <meshStandardMaterial color={scaleColor} emissive="#13343a" emissiveIntensity={0.3} roughness={0.45} metalness={0.2} />
          </mesh>
        )
      })}

      {/* splash ripple ring on the surface */}
      <mesh ref={ringRef} position={[0, -0.85, 1]} rotation={[-Math.PI / 2, 0, 0]} visible={false}>
        <ringGeometry args={[0.6, 0.9, 28]} />
        <meshStandardMaterial color="#a8d8ec" emissive="#6fb6d6" emissiveIntensity={0.6} transparent opacity={0.5} side={THREE.DoubleSide} />
      </mesh>
    </group>
  )
}
