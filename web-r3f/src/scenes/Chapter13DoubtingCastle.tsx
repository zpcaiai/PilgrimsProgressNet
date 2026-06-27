import { useState, useRef, useId, useEffect } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { NPCMarker } from '../components/three/NPCMarker'
import { CompanionParty } from '../components/three/CompanionParty'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { ModelProp } from '../components/three/ModelProp'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { rememberKeyOfPromise, escapeDoubtingCastle } from '../systems/bossSystem'
import { audio } from '../systems/audio/AudioEngine'
import { playerPos } from '../systems/playerPos'
import { setObstacle, removeObstacle } from '../systems/collision'

/** A row of crenellations (merlons) along a wall top — reads the castle as a fortress. */
function Crenellations({ length, axis = 'x', y, color = '#161318' }: { length: number; axis?: 'x' | 'z'; y: number; color?: string }) {
  const n = Math.max(2, Math.floor(length / 1.7))
  const start = -((n - 1) * 1.7) / 2
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const off = start + i * 1.7
        const pos: [number, number, number] = axis === 'x' ? [off, y, 0] : [0, y, off]
        return (
          <mesh key={i} position={pos} castShadow>
            <boxGeometry args={axis === 'x' ? [0.9, 0.9, 0.8] : [0.8, 0.9, 0.9]} />
            <meshStandardMaterial color={color} />
          </mesh>
        )
      })}
    </>
  )
}

/** A round corner tower with a crenellated crown. */
function Tower({ position }: { position: [number, number, number] }) {
  return (
    <group position={position}>
      <Collider circle={[position[0], position[2], 1.5]} />
      <mesh position={[0, 6.5, 0]} castShadow receiveShadow>
        <cylinderGeometry args={[1.5, 1.8, 13, 16]} />
        <meshStandardMaterial color="#211c22" roughness={0.95} metalness={0} />
      </mesh>
      <mesh position={[0, 13, 0]}>
        <cylinderGeometry args={[1.9, 1.9, 0.5, 12]} />
        <meshStandardMaterial color="#1a161b" />
      </mesh>
      {[0, 1, 2, 3, 4, 5].map((i) => {
        const a = (i / 6) * Math.PI * 2
        return (
          <mesh key={i} position={[Math.cos(a) * 1.7, 13.6, Math.sin(a) * 1.7]} castShadow>
            <boxGeometry args={[0.5, 0.9, 0.5]} />
            <meshStandardMaterial color="#1a161b" />
          </mesh>
        )
      })}
    </group>
  )
}

/** Giant Despair — a towering jailer who prowls behind the bars, looms toward the
 *  pilgrim, and is solid (no walking through him). His club lowers as resolve grows. */
function GiantDespair({ defeated, cowed }: { defeated: boolean; cowed: boolean }) {
  const ref = useRef<THREE.Group>(null)
  const id = useId()
  const clubAngle = defeated ? -1.3 : cowed ? -0.1 : -0.5
  useEffect(() => () => removeObstacle(id), [id])
  useFrame((_, dt) => {
    const g = ref.current
    if (!g) return
    if (defeated) {
      g.position.z = THREE.MathUtils.lerp(g.position.z, -22, dt * 0.6)
      g.position.x = THREE.MathUtils.lerp(g.position.x, -6, dt * 0.6)
      removeObstacle(id)
      return
    }
    // Prowl behind the bars: pace toward the pilgrim's side, looming, but kept on
    // the far side of the cell (z ≈ -12) so he never clips through the bars.
    const tx = THREE.MathUtils.clamp(playerPos.x, -7, 8)
    g.position.x = THREE.MathUtils.lerp(g.position.x, tx, dt * 0.6)
    g.position.z = -12
    g.rotation.y = Math.atan2(playerPos.x - g.position.x, playerPos.z - g.position.z)
    setObstacle(id, { kind: 'circle', x: g.position.x, z: g.position.z, r: 1.5 })
  })
  return (
    <group ref={ref} position={[5.5, 0, -12]}>
      <mesh position={[0, 3.2, 0]} castShadow><boxGeometry args={[2.6, 6.4, 1.8]} /><meshStandardMaterial color={defeated ? '#2a2622' : '#3a322a'} /></mesh>
      <mesh position={[0, 6.9, 0]} castShadow><boxGeometry args={[1.7, 1.6, 1.6]} /><meshStandardMaterial color="#4a3f34" /></mesh>
      <mesh position={[-0.45, 7.0, 0.8]}><sphereGeometry args={[0.13, 10, 10]} /><meshStandardMaterial color="#caa23a" emissive="#caa23a" emissiveIntensity={defeated ? 0.2 : 1.4} /></mesh>
      <mesh position={[0.45, 7.0, 0.8]}><sphereGeometry args={[0.13, 10, 10]} /><meshStandardMaterial color="#caa23a" emissive="#caa23a" emissiveIntensity={defeated ? 0.2 : 1.4} /></mesh>
      {/* arms */}
      <mesh position={[-1.6, 3.6, 0.2]} rotation={[0, 0, 0.2]} castShadow><boxGeometry args={[0.7, 3.4, 0.8]} /><meshStandardMaterial color="#342c25" /></mesh>
      <mesh position={[1.6, 3.6, 0.2]} rotation={[0, 0, -0.2]} castShadow><boxGeometry args={[0.7, 3.4, 0.8]} /><meshStandardMaterial color="#342c25" /></mesh>
      <mesh position={[1.9, 3.4, 0.6]} rotation={[0, 0, clubAngle]} castShadow><cylinderGeometry args={[0.18, 0.34, 3.4, 8]} /><meshStandardMaterial color="#2e2620" /></mesh>
      <mesh position={[2.6, 5.0, 0.6]} rotation={[0, 0, clubAngle]} castShadow><sphereGeometry args={[0.5, 10, 10]} /><meshStandardMaterial color="#241d18" /></mesh>
      <Html center position={[0, 8.2, 0]} distanceFactor={24}><div className="px-2 py-0.5 text-[11px] bg-black/70 rounded whitespace-nowrap pointer-events-none">{defeated ? '绝望巨人退去' : '绝望巨人 Giant Despair'}</div></Html>
    </group>
  )
}

function Bars({ open }: { open: boolean }) {
  return (
    <group position={[0, 0, -5]}>
      {/* solid sections of the grate block the pilgrim; the gate opens on escape */}
      <Collider box={[-3, -5, 4.4, 0.5]} />
      <Collider box={[3, -5, 4.4, 0.5]} />
      {!open && <Collider box={[0, -5, 4, 0.5]} />}
      {[-4, -3.3, -2.6, -1.9, 1.9, 2.6, 3.3, 4].map((x) => (
        <mesh key={x} position={[x, 1.6, 0]} castShadow><cylinderGeometry args={[0.08, 0.08, 3.2, 8]} /><meshStandardMaterial color="#1a1714" metalness={0.5} /></mesh>
      ))}
      <group position={[-1.9, 0, 0]} rotation={[0, open ? -1.2 : 0, 0]}>
        {[0, 0.7, 1.4, 2.6, 3.3].map((x) => (
          <mesh key={x} position={[x, 1.6, 0]} castShadow><cylinderGeometry args={[0.08, 0.08, 3.2, 8]} /><meshStandardMaterial color="#241f1a" metalness={0.5} /></mesh>
        ))}
        <mesh position={[1.7, 0.3, 0]}><boxGeometry args={[3.4, 0.12, 0.12]} /><meshStandardMaterial color="#241f1a" /></mesh>
        <mesh position={[1.7, 2.9, 0]}><boxGeometry args={[3.4, 0.12, 0.12]} /><meshStandardMaterial color="#241f1a" /></mesh>
      </group>
    </group>
  )
}

export function Chapter13DoubtingCastle() {
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const mutate = useGameStore((s) => s.mutate)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const gs = useGameStore((s) => s.gameState)
  const foundKey = !!gs.storyFlags.found_key_of_promise
  const escaped = !!gs.storyFlags.escaped_doubting_castle

  const [resolve, setResolve] = useState(foundKey ? 100 : 0)
  const ready = resolve >= 66

  const pray = () => {
    if (ready) return
    audio.sfx('chime')
    applyEffects({ hope: 8, despair: -8, faith: 4 })
    setResolve((r) => Math.min(100, r + 34))
    showToast('你与盼望在牢中一同祷告、歌唱——黑暗里升起一线微光，绝望的钳制松动了。')
  }
  const remember = () => {
    if (foundKey) return
    mutate((s) => rememberKeyOfPromise(s)); audio.sfx('pickup')
    showToast('“我这囚犯，怀里一直揣着一把名叫‘应许’的钥匙，它能开疑惑堡里任何一把锁！”')
  }
  const escape = () => {
    if (escaped || !foundKey) return
    mutate((s) => escapeDoubtingCastle(s)); audio.sfx('whoosh')
    showToast('应许之钥转动，牢门、外门、铁闸应声而开——你与盼望逃出了疑惑堡，绝望巨人追赶不及。')
  }

  return (
    <group>
      <fog attach="fog" args={['#0c0a0c', 18, 70]} />
      <NaturalGround detail size={[40, 50]} color="#1a1618" amp={0} />
      {/* the whole fortress looming beyond the wall — real generated GLB (distant, no collision) */}
      <ModelProp src="/models/doubting_castle.glb" fallback={null} position={[0, 0, -40]} rotation={[0, Math.PI, 0]} scale={2.6} />

      {/* --- curtain walls of the fortress (all solid) --- */}
      <group position={[0, 5, -16]}><mesh receiveShadow castShadow><boxGeometry args={[34, 12, 0.6]} /><meshStandardMaterial color="#221d22" roughness={0.96} metalness={0} /></mesh><Crenellations length={32} y={6.4} /></group>
      <Collider box={[0, -16, 34, 0.6]} />
      <group position={[-11, 5, -6]}><mesh castShadow><boxGeometry args={[0.6, 12, 22]} /><meshStandardMaterial color="#1d191d" roughness={0.96} metalness={0} /></mesh><group position={[0, 1.4, 0]}><Crenellations length={20} axis="z" y={5} /></group></group>
      <Collider box={[-11, -6, 0.6, 22]} />
      <group position={[11, 5, -6]}><mesh castShadow><boxGeometry args={[0.6, 12, 22]} /><meshStandardMaterial color="#1d191d" roughness={0.96} metalness={0} /></mesh><group position={[0, 1.4, 0]}><Crenellations length={20} axis="z" y={5} /></group></group>
      <Collider box={[11, -6, 0.6, 22]} />

      {/* front gatehouse: two wall sections leave a central gate the pilgrim enters by */}
      <mesh position={[-6.6, 5, 5]} castShadow><boxGeometry args={[8.2, 12, 0.6]} /><meshStandardMaterial color="#211c21" roughness={0.96} metalness={0} /></mesh>
      <Collider box={[-6.6, 5, 8.2, 0.6]} />
      <mesh position={[6.6, 5, 5]} castShadow><boxGeometry args={[8.2, 12, 0.6]} /><meshStandardMaterial color="#211c21" roughness={0.96} metalness={0} /></mesh>
      <Collider box={[6.6, 5, 8.2, 0.6]} />
      <mesh position={[0, 10.5, 5]} castShadow><boxGeometry args={[5, 3, 0.7]} /><meshStandardMaterial color="#26202a" /></mesh>

      {/* four corner towers */}
      <Tower position={[-11, 0, 5]} />
      <Tower position={[11, 0, 5]} />
      <Tower position={[-11, 0, -16]} />
      <Tower position={[11, 0, -16]} />

      {/* a barred window high on the back wall, glowing once you escape */}
      <mesh position={[-6, 6.5, -15.6]}><boxGeometry args={[2, 2, 0.3]} /><meshStandardMaterial color="#26506a" emissive="#3a6a88" emissiveIntensity={escaped ? 1.2 : 0.5} /></mesh>

      <GiantDespair defeated={escaped} cowed={ready} />
      <Bars open={escaped} />

      {/* struggle: pray with Hopeful to build resolve */}
      {!ready && (
        <group position={[-2.4, 0, 2.5]} onClick={(e) => { e.stopPropagation(); pray() }}
          onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
          <mesh position={[0, 1, 0]}><sphereGeometry args={[0.34, 16, 16]} /><meshStandardMaterial color="#7fa0d0" emissive="#5a7ac0" emissiveIntensity={0.7} /></mesh>
          <Html center position={[0, 2, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">与盼望一同祷告歌唱（{Math.round(resolve)}%）</div></Html>
        </group>
      )}

      {/* remember the key — unlocked once resolve breaks despair's grip */}
      {ready && !foundKey && (
        <group position={[-2, 0, 3]} onClick={(e) => { e.stopPropagation(); remember() }}
          onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
          <mesh position={[0, 1.1, 0]}><sphereGeometry args={[0.3, 16, 16]} /><meshStandardMaterial color="#ffe08a" emissive="#ffcf6a" emissiveIntensity={1.4} /></mesh>
          <Html center position={[0, 2, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">想起怀中的「应许之钥」（点击）</div></Html>
        </group>
      )}

      {/* unlock & escape */}
      {foundKey && (
        <group position={[0, 0, -5]} onClick={(e) => { e.stopPropagation(); escape() }}
          onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
          <mesh position={[0, 1.6, 0.4]} visible={!escaped}><boxGeometry args={[3.8, 3.2, 0.2]} /><meshBasicMaterial transparent opacity={0} depthWrite={false} /></mesh>
          <Html center position={[0, 3.4, 0]} distanceFactor={18}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">{escaped ? '✓ 已逃出疑惑堡' : '用应许之钥开牢门（点击）'}</div></Html>
        </group>
      )}

      {/* torch lights give the stone real depth */}
      <pointLight position={[-9, 4.5, 2]} intensity={6} distance={18} color="#ff9a4a" />
      <pointLight position={[9, 4.5, 2]} intensity={6} distance={18} color="#ff9a4a" />
      <pointLight position={[0, 5, -14]} intensity={4} distance={20} color="#5a6a9a" />
      {escaped && <pointLight position={[0, 6, 2]} intensity={10} distance={34} color="#ffe0a0" />}

      <CompanionParty anchors={[[-2.6, 0, 8], [2.6, 0, 8]]} onTalk={() => showToast('盼望在牢中对你歌唱：“天总会亮的，不要让绝望巨人骗了我们。”')} />
      <NPCMarker name="绝望巨人(威吓)" color="#4a3f34" position={[4, 0, -8]} solid={false} onTalk={() => openDialogue('dialogue_giant_despair_threat')} />

      <hemisphereLight args={['#2a2630', '#070608', 0.35]} />
      <Player start={[0, 0, 8]} />
    </group>
  )
}
