import { useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock } from '../components/three/NatureKit'
import { PilgrimFamily } from '../components/three/PilgrimFamily'
import { surfaceDetailProps } from '../lib/detailMaps'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'

/** The pilgrim's own home, marked with a cross on the gable — where the journey begins. */
function PilgrimHome() {
  return (
    <group position={[-7, 0, 5]}>
      <mesh position={[0, 1.3, 0]} castShadow receiveShadow><boxGeometry args={[3.6, 2.6, 3.4]} /><meshStandardMaterial color="#574a40" /></mesh>
      <mesh position={[0, 3.0, 0]} rotation={[0, Math.PI / 4, 0]} castShadow><coneGeometry args={[2.7, 1.4, 4]} /><meshStandardMaterial color="#6a4f3a" /></mesh>
      {/* lit doorway + window */}
      <mesh position={[0, 0.8, 1.72]}><planeGeometry args={[0.9, 1.6]} /><meshStandardMaterial color="#2a221c" emissive="#ffb45a" emissiveIntensity={0.5} /></mesh>
      <mesh position={[1.1, 1.5, 1.72]}><planeGeometry args={[0.7, 0.7]} /><meshStandardMaterial color="#2a221c" emissive="#ffb45a" emissiveIntensity={0.4} /></mesh>
      {/* cross on the gable */}
      <mesh position={[0, 4.3, 0]} castShadow><boxGeometry args={[0.16, 1.1, 0.16]} /><meshStandardMaterial color="#d8c49a" emissive="#e8d28a" emissiveIntensity={0.7} /></mesh>
      <mesh position={[0, 4.5, 0]} castShadow><boxGeometry args={[0.55, 0.16, 0.16]} /><meshStandardMaterial color="#d8c49a" emissive="#e8d28a" emissiveIntensity={0.7} /></mesh>
      <pointLight position={[0, 4.4, 0.6]} intensity={2.4} distance={7} color="#ffe0a8" />
      <Html center position={[0, 5.3, 0]} distanceFactor={18}><div className="px-2 py-0.5 text-[11px] bg-black/55 rounded whitespace-nowrap pointer-events-none">主角的家 ✝</div></Html>
    </group>
  )
}

type Block = { x: number; z: number; w: number; d: number; h: number; color: string; lit: boolean; pitched: boolean; id: number }

/** A multi-storey city building: brick-detailed walls, a flat parapet (or, rarely,
 *  a low pitched) roof, and rows of mostly-dark windows (a few lit) — urban, not a hut. */
function Building({ x, z, w, d, h, color, lit, pitched }: Omit<Block, 'id'>) {
  const wins = useMemo(() => {
    const arr: [number, number][] = []
    const floors = Math.max(1, Math.floor(h / 2.2))
    for (let f = 0; f < floors; f++) for (const wx of [-w * 0.26, w * 0.26]) arr.push([wx, 1.0 + f * 2.0])
    return arr
  }, [w, h])
  return (
    <group position={[x, 0, z]}>
      <Collider box={[x, z, w, d]} />
      <mesh position={[0, h / 2, 0]} castShadow receiveShadow>
        <boxGeometry args={[w, h, d]} />
        <meshStandardMaterial color={color} roughness={0.95} metalness={0} {...surfaceDetailProps({ normalScale: 0.6 })} />
      </mesh>
      {pitched ? (
        <mesh position={[0, h + 0.55, 0]} rotation={[0, Math.PI / 4, 0]} castShadow>
          <coneGeometry args={[Math.max(w, d) * 0.74, 1.2, 4]} />
          <meshStandardMaterial color="#26201b" roughness={0.92} metalness={0} />
        </mesh>
      ) : (
        <mesh position={[0, h + 0.18, 0]} castShadow>
          <boxGeometry args={[w + 0.34, 0.36, d + 0.34]} />
          <meshStandardMaterial color="#2b2520" roughness={0.95} metalness={0} />
        </mesh>
      )}
      {wins.map(([wx, wy], i) => (
        <mesh key={i} position={[wx, wy, d / 2 + 0.03]}>
          <planeGeometry args={[0.52, 0.78]} />
          <meshStandardMaterial color="#15110c" emissive={lit && i % 3 === 0 ? '#ffae54' : '#000000'} emissiveIntensity={lit && i % 3 === 0 ? 0.7 : 0} roughness={0.85} />
        </mesh>
      ))}
    </group>
  )
}

/** Rising smoke + ember glow from a burning quarter of the doomed city. */
function SmokePlume({ position }: { position: [number, number, number] }) {
  const g = useRef<THREE.Group>(null)
  useFrame((s) => {
    if (!g.current) return
    const t = s.clock.elapsedTime
    g.current.children.forEach((m, i) => {
      if (!(m as THREE.Mesh).isMesh) return
      const o = (t * 0.5 + i * 0.8) % 4
      m.position.y = 1.2 + o * 1.7
      m.scale.setScalar(0.6 + o * 0.55)
      const mat = (m as THREE.Mesh).material as THREE.MeshStandardMaterial
      mat.opacity = Math.max(0, 0.45 - o * 0.11)
    })
  })
  return (
    <group position={position}>
      <pointLight position={[0, 1.2, 0]} intensity={5} distance={14} color="#ff6a2a" />
      <group ref={g}>
        {[0, 1, 2, 3, 4].map((i) => (
          <mesh key={i}><sphereGeometry args={[0.7, 8, 8]} /><meshStandardMaterial color="#26211c" transparent opacity={0.4} roughness={1} depthWrite={false} /></mesh>
        ))}
      </group>
    </group>
  )
}

function CityBuildings() {
  const blocks = useMemo<Block[]>(() => {
    const r = (n: number) => { const v = Math.sin(n * 99.71) * 43758.5; return v - Math.floor(v) }
    const out: Block[] = []
    const palette = ['#3a322c', '#332b26', '#42372f', '#2e2824']
    let id = 10
    for (let row = 0; row < 7; row++) {
      const z = 1 - row * 5.6
      for (const side of [-1, 1]) {
        const x = side * (7.5 + r(id) * 3.6)
        out.push({
          x, z,
          w: 3 + r(id * 2) * 2.6,
          d: 3 + r(id * 3) * 2,
          h: 4.5 + r(id * 5) * 7,
          pitched: r(id * 7) < 0.22,
          lit: r(id * 11) < 0.34,
          color: palette[id % palette.length],
          id,
        })
        id++
      }
    }
    return out
  }, [])
  return (
    <>
      {blocks.map((b) => <Building key={b.id} {...b} />)}
      {/* tall ruined towers give a real city skyline */}
      <Building x={-12.5} z={-18} w={4} d={4} h={15} color="#352d27" pitched lit={false} />
      <Building x={12.5} z={-26} w={4.6} d={4.6} h={17.5} color="#2f2823" pitched lit />
      {/* burning quarters */}
      <SmokePlume position={[10, 0, -22]} />
      <SmokePlume position={[-11, 0, -30]} />
      <SmokePlume position={[8.5, 0, -9]} />
    </>
  )
}

export function Chapter01CityOfDestruction() {
  const openDialogue = useUiStore((s) => s.openDialogue)
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const chapel = getChapelById('chapel_city_ruins')

  return (
    <group>
      <fog attach="fog" args={['#221c18', 20, 78]} />
      {/* ground */}
      <NaturalGround detail size={[64, 84]} color="#2a2622" />
      {/* road */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.01, -14]} receiveShadow>
        <planeGeometry args={[6, 64]} />
        <meshStandardMaterial color="#3a342e" roughness={1} metalness={0} />
      </mesh>
      <CityBuildings />
      <PilgrimHome />
      <Collider box={[-7, 5, 3.6, 3.4]} />{/* the pilgrim's home is solid */}
      {/* the great city wall closing the far side; the road leaves through its gate */}
      <mesh position={[-10.5, 4, -36]} castShadow receiveShadow><boxGeometry args={[17, 8, 1.6]} /><meshStandardMaterial color="#403730" roughness={0.95} metalness={0} {...surfaceDetailProps({ normalScale: 0.6 })} /></mesh>
      <mesh position={[10.5, 4, -36]} castShadow receiveShadow><boxGeometry args={[17, 8, 1.6]} /><meshStandardMaterial color="#403730" roughness={0.95} metalness={0} {...surfaceDetailProps({ normalScale: 0.6 })} /></mesh>
      <mesh position={[-10.5, 8.3, -36]}><boxGeometry args={[17, 0.6, 2]} /><meshStandardMaterial color="#352e28" roughness={0.95} /></mesh>
      <mesh position={[10.5, 8.3, -36]}><boxGeometry args={[17, 0.6, 2]} /><meshStandardMaterial color="#352e28" roughness={0.95} /></mesh>
      <Collider box={[-10.5, -36, 17, 1.6]} />
      <Collider box={[10.5, -36, 17, 1.6]} />
      {/* corner towers */}
      {[-19, 19].map((tx) => (
        <group key={tx}>
          <Collider circle={[tx, -36, 2.3]} />
          <mesh position={[tx, 6, -36]} castShadow receiveShadow><cylinderGeometry args={[2, 2.3, 13, 14]} /><meshStandardMaterial color="#3a322c" roughness={0.95} metalness={0} {...surfaceDetailProps({ normalScale: 0.5 })} /></mesh>
          <mesh position={[tx, 12.8, -36]}><cylinderGeometry args={[2.4, 2.4, 0.6, 14]} /><meshStandardMaterial color="#312a24" roughness={0.95} /></mesh>
        </group>
      ))}
      {/* cold light through the gate (the way out) + a red judgment glow on the city */}
      <pointLight position={[0, 5, -34]} intensity={8} distance={26} color="#9fb6ff" />
      <pointLight position={[0, 14, -20]} intensity={5} distance={60} color="#b8401f" />

      {/* rubble & broken masonry in the streets (urban debris, not a meadow) */}
      <Rock position={[-4.2, 0, -3]} scale={0.7} seed={2} color="#4a423a" />
      <Rock position={[4.4, 0, -7]} scale={0.9} seed={5} color="#52483f" />
      <Rock position={[-5, 0, -19]} scale={0.8} seed={8} color="#463f38" />
      <Rock position={[5, 0, -24]} scale={1.0} seed={11} color="#4e453c" />
      <Rock position={[3.6, 0, 4]} scale={0.55} seed={3} color="#4a423a" />
      {/* a couple of fallen roof-beams */}
      {[[-3.4, -10, 0.5], [4, -15, -0.6]].map(([x, z, r], i) => (
        <mesh key={i} position={[x, 0.16, z]} rotation={[0, r, Math.PI / 2]} castShadow>
          <cylinderGeometry args={[0.16, 0.2, 2.6, 6]} />
          <meshStandardMaterial color="#2e251d" roughness={0.95} metalness={0} />
        </mesh>
      ))}
      {/* distant light beacon */}
      <mesh position={[0, 9, -78]}><sphereGeometry args={[3, 20, 20]} /><meshStandardMaterial color="#fff0c0" emissive="#ffe6a0" emissiveIntensity={2} /></mesh>
      <pointLight position={[0, 9, -78]} intensity={30} distance={120} color="#ffe6a0" />
      {/* ember glow over the doomed city */}
      <pointLight position={[-14, 6, 22]} intensity={6} distance={40} color="#ff7a3a" />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* the pilgrim's wife (same height as him) and their two children, by the home */}
      <PilgrimFamily position={[-5, 0, 3.4]} onTalk={() => showToast('你的妻子抱着两个孩子站在家门口，含泪劝你回来——他们却不肯与你一同上路。')} />

      <NPCMarker name="Evangelist 传福音者" color="#27407a" position={[2, 0, -4]} onTalk={() => openDialogue('dialogue_evangelist_intro')} />
      <NPCMarker name="Obstinate 顽固" color="#5a5048" position={[-4, 0, 2]} onTalk={() => openDialogue('dialogue_obstinate_stay')} />
      <NPCMarker name="Pliable 易迁" color="#6a8a5a" position={[5, 0, 1]} onTalk={() => openDialogue('dialogue_pliable_join')} />

      <Player start={[0, 0, 6]} />
    </group>
  )
}
