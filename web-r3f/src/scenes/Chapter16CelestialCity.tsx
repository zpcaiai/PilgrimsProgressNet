import { useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { CompanionParty } from '../components/three/CompanionParty'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { HolyLight } from '../components/three/HolyLight'
import { ModelProp } from '../components/three/ModelProp'
import { getChapelById } from '../lib/content'

// Real generated hero model (tools/gen_models/build_props.py); set undefined to use the procedural gate.
const CELESTIAL_GATE_SRC: string | undefined = '/models/celestial_gate.glb'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

/** Shining ones at the gate, gently bobbing. */
function ShiningOne({ x, z }: { x: number; z: number }) {
  const ref = useRef<THREE.Group>(null)
  useFrame((state) => { if (ref.current) ref.current.position.y = Math.sin(state.clock.elapsedTime * 1.2 + x) * 0.12 })
  return (
    <group ref={ref} position={[x, 0, z]}>
      <mesh position={[0, 1, 0]} castShadow><capsuleGeometry args={[0.32, 1, 4, 8]} /><meshStandardMaterial color="#fff8e0" emissive="#ffe6a0" emissiveIntensity={0.7} /></mesh>
      <mesh position={[0, 1.9, 0]}><sphereGeometry args={[0.26, 16, 16]} /><meshStandardMaterial color="#fffdf0" emissive="#fff0c0" emissiveIntensity={0.6} /></mesh>
      {/* halo */}
      <mesh position={[0, 2.3, 0]} rotation={[Math.PI / 2, 0, 0]}><torusGeometry args={[0.28, 0.03, 8, 20]} /><meshStandardMaterial color="#ffe890" emissive="#ffe890" emissiveIntensity={1.2} /></mesh>
    </group>
  )
}

/** Procedural fallback for the celestial gate (used if the GLB is absent). */
function CelestialGateStructure({ entered }: { entered: boolean }) {
  return (
    <group>
      <mesh position={[-3, 4, 0]} castShadow><boxGeometry args={[1.4, 8, 1.4]} /><meshStandardMaterial color="#ffe6a8" emissive="#ffdf90" emissiveIntensity={0.35} metalness={0.9} roughness={0.25} /></mesh>
      <mesh position={[3, 4, 0]} castShadow><boxGeometry args={[1.4, 8, 1.4]} /><meshStandardMaterial color="#ffe6a8" emissive="#ffdf90" emissiveIntensity={0.35} metalness={0.9} roughness={0.25} /></mesh>
      <mesh position={[0, 8.4, 0]} castShadow><boxGeometry args={[7.4, 1.4, 1.4]} /><meshStandardMaterial color="#ffe6a0" emissive="#ffcf6a" emissiveIntensity={0.4} metalness={0.9} roughness={0.25} /></mesh>
      <mesh position={[0, 3.4, 0]}><planeGeometry args={[4.4, 6.8]} /><meshStandardMaterial color="#fffdf0" emissive="#fff6d0" emissiveIntensity={entered ? 2.4 : 1.4} side={THREE.DoubleSide} /></mesh>
      <mesh position={[0, 9.6, 0]}><cylinderGeometry args={[0.7, 0.8, 0.5, 16, 1, true]} /><meshStandardMaterial color="#ffe27a" emissive="#ffcf6a" emissiveIntensity={1.4} side={THREE.DoubleSide} /></mesh>
    </group>
  )
}

export function Chapter16CelestialCity() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const completeChapter = useGameStore((s) => s.completeChapter)
  const entered = useGameStore((s) => !!s.gameState.storyFlags.entered_celestial_city)
  const chapel = getChapelById('chapel_celestial_city')

  const enter = () => {
    if (entered) return
    applyEffects({ hope: 20, faith: 12, love: 12, fear: -20, despair: -15, burden: -20 }, ['entered_celestial_city'], ['crown_of_life'])
    completeChapter('chapter_16')
    showToast('城门为你敞开，钟声大作，众圣徒欢呼迎接。重担早已卸下，如今你戴上了生命的冠冕。')
  }

  return (
    <group>
      <fog attach="fog" args={['#fdf3d0', 44, 120]} />
      <NaturalGround detail size={[70, 80]} color="#d8c47a" amp={0.04} />
      {/* street of gold */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, -6]} receiveShadow><planeGeometry args={[6, 36]} /><meshStandardMaterial color="#e8cf7a" emissive="#caa23a" emissiveIntensity={0.18} metalness={0.4} roughness={0.45} /></mesh>

      {/* the great gate — real GLB hero model with a procedural fallback */}
      <group position={[0, 0, -11]}>
        <ModelProp src={CELESTIAL_GATE_SRC} scale={0.82} fallback={<CelestialGateStructure entered={entered} />} />
        <pointLight position={[0, 4, 2]} intensity={entered ? 26 : 16} distance={50} color="#fff0c0" />
      </group>
      {/* the gate's pillars are solid (the doorway between them stays open) */}
      <Collider box={[-3, -11, 1.4, 1.4]} />
      <Collider box={[3, -11, 1.4, 1.4]} />

      {/* towers behind the wall */}
      {[-9, -6, 6, 9].map((x, i) => (
        <group key={x}>
          <Collider box={[x, -16, 2.4, 2.4]} />
          <mesh position={[x, 5 + (i % 2) * 2, -16]} castShadow><boxGeometry args={[2.4, 10 + (i % 2) * 4, 2.4]} /><meshStandardMaterial color="#ffeaa6" emissive="#ffd98a" emissiveIntensity={0.4} metalness={0.85} roughness={0.3} /></mesh>
        </group>
      ))}

      {/* divine glory streaming from above the gate */}
      <HolyLight position={[0, 10, -11]} color="#fff1c4" radius={6.5} intensity={entered ? 1.6 : 1.05} />

      <ShiningOne x={-2.2} z={-8} />
      <ShiningOne x={2.2} z={-8} />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* enter the city */}
      <group position={[0, 0, -9]} onClick={(e) => { e.stopPropagation(); enter() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 2, 0]} visible={!entered}><boxGeometry args={[4, 6, 1]} /><meshBasicMaterial transparent opacity={0} depthWrite={false} /></mesh>
        <Html center position={[0, 6.6, 0]} distanceFactor={20}><div className="px-2 py-0.5 text-[11px] bg-black/55 rounded whitespace-nowrap pointer-events-none">{entered ? '✓ 已进入天城' : '进入天城的门（点击）'}</div></Html>
      </group>

      <NPCMarker name="守门的 Gatekeeper" color="#caa86a" position={[-4.5, 0, -6]} onTalk={() => showToast('守门的问：“你的凭据呢？”你取出十架前所得的确据书卷——门便开了。')} />
      <CompanionParty anchors={[[2.6, 0, 7]]} onTalk={() => showToast('盼望与你一同走到城门前——你们一路彼此扶持，终于同到。')} />

      <hemisphereLight args={['#fff6da', '#9a8a5a', 0.9]} />
      <directionalLight position={[0, 20, 8]} intensity={1.3} color="#fff3d0" />
      <Player start={[0, 0, 9]} />
    </group>
  )
}
