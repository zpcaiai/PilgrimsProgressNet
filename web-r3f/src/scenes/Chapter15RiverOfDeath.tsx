import { useRef, useEffect, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html, MeshReflectorMaterial } from '@react-three/drei'
import * as THREE from 'three'
import { detailNormalMap } from '../lib/detailMaps'
import { Chapel } from '../components/three/Chapel'
import { CompanionParty } from '../components/three/CompanionParty'
import { Player } from '../components/three/Player'
import { RiverBeast } from '../components/three/RiverBeast'
import { NaturalGround } from '../components/three/NaturalGround'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { setWaterZone } from '../systems/water'

/** River surface — its height (how deep the water feels) rises with `sink`. */
function River({ sink }: { sink: number }) {
  const ref = useRef<THREE.Mesh>(null)
  const targetY = THREE.MathUtils.lerp(0.12, 1.95, sink)
  // An independent (cloned) normal map that scrolls → moving ripples on the water,
  // without disturbing the shared detail map used by ground/props.
  const waterNormal = useMemo(() => {
    const tx = detailNormalMap().clone()
    tx.needsUpdate = true
    tx.wrapS = tx.wrapT = THREE.RepeatWrapping
    tx.repeat.set(5, 3.5)
    return tx
  }, [])
  // Clear the water band when leaving the chapter, so other scenes don't "swim".
  useEffect(() => () => setWaterZone(null), [])
  useFrame((state, dt) => {
    const m = ref.current
    if (!m) return
    m.position.y = THREE.MathUtils.lerp(m.position.y, targetY, 0.06) + Math.sin(state.clock.elapsedTime * 1.5) * 0.03
    waterNormal.offset.y += dt * 0.035
    waterNormal.offset.x += dt * 0.012
    // Publish the wet band so the Player sinks to the waist and swims while in it.
    setWaterZone({ zMin: -29, zMax: 1, surfaceY: m.position.y })
  })
  const deep = new THREE.Color('#3a6f86').lerp(new THREE.Color('#0a1622'), sink)
  return (
    <mesh ref={ref} rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.12, -14]}>
      <planeGeometry args={[44, 30]} />
      <MeshReflectorMaterial
        mirror={0.6}
        color={deep}
        normalMap={waterNormal}
        normalScale={new THREE.Vector2(0.25, 0.25)}
        metalness={0.25}
        roughness={0.18}
        transparent
        opacity={0.9}
        resolution={512}
        blur={[260, 80]}
        mixBlur={1.2}
        mixStrength={2.6}
        depthScale={1}
        minDepthThreshold={0.4}
        maxDepthThreshold={1.2}
      />
    </mesh>
  )
}

/** The shining city on the far shore. */
function FarCity() {
  return (
    <group position={[0, 0, -40]}>
      {[-4, -2, 0, 2, 4].map((x, i) => (
        <mesh key={x} position={[x * 1.5, 4 + (i % 2) * 1.5, 0]}><boxGeometry args={[1.7, 8 + (i % 2) * 3, 1.7]} /><meshStandardMaterial color="#fff0c0" emissive="#ffdf90" emissiveIntensity={1.4} /></mesh>
      ))}
      <mesh position={[0, 0.5, 2]}><boxGeometry args={[10, 1, 0.6]} /><meshStandardMaterial color="#caa23a" emissive="#caa23a" emissiveIntensity={0.6} /></mesh>
      <pointLight position={[0, 10, 5]} intensity={16} distance={48} color="#ffe6b0" />
    </group>
  )
}

export function Chapter15RiverOfDeath() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const gs = useGameStore((s) => s.gameState)
  const s = gs.spiritualStats
  const crossed = !!gs.storyFlags.crossed_river
  const chapel = getChapelById('chapel_river_of_death')

  // Depth of the river = the pilgrim's fear/doubt/despair minus his faith/hope.
  const sink = Math.max(0.05, Math.min(0.98, ((s.fear + s.doubt + s.despair) - (s.faith + s.hope)) / 120 + 0.45))
  const depthCN = crossed ? '已上彼岸' : sink < 0.3 ? '脚踏实地' : sink < 0.55 ? '水深及腰' : sink < 0.78 ? '水深及胸' : '水将没顶——盼望，扶住我！'

  const cross = () => {
    if (crossed) return
    const deep = sink > 0.7
    applyEffects({ faith: 8, hope: 12, fear: -12, despair: -8 }, ['crossed_river', 'crossing_river'])
    showToast(deep
      ? '波涛几乎没顶，盼望在深水中托住你：“弟兄，我觉得脚下是好的、是实在的！”——你终于上了彼岸。'
      : '你定睛仰望对岸，脚下的水竟变浅了，你稳稳渡过了死河。')
  }

  return (
    <group>
      <fog attach="fog" args={['#1a2230', 26, 96]} />
      <NaturalGround detail size={[60, 80]} color="#22303a" />
      {/* near shore the pilgrim stands on */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.05, 7]} receiveShadow><planeGeometry args={[44, 14]} /><meshStandardMaterial color="#3a4a40" roughness={1} metalness={0} /></mesh>

      <River sink={sink} />
      <FarCity />
      {!crossed && <RiverBeast />}

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* the crossing: step into the river toward the city */}
      <group position={[0, 0, -3]} onClick={(e) => { e.stopPropagation(); cross() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 1.5, 0]}><boxGeometry args={[0.12, 1, 0.12]} /><meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={0.8} /></mesh>
        <mesh position={[0, 1.75, 0]}><boxGeometry args={[0.5, 0.12, 0.12]} /><meshStandardMaterial color="#f3ecd0" emissive="#e8d28a" emissiveIntensity={0.8} /></mesh>
        <Html center position={[0, 2.6, 0]} distanceFactor={18}><div className="px-2 py-0.5 text-[11px] bg-black/65 rounded whitespace-nowrap pointer-events-none">{crossed ? '✓ 凭信渡过死河' : '定睛对岸，举步入河（点击）'}</div></Html>
      </group>

      {/* live depth gauge — driven by faith/hope vs fear/doubt/despair */}
      <Html center position={[0, 3.6, 6]} distanceFactor={22}>
        <div className="px-3 py-1 bg-black/55 rounded text-[11px] text-center whitespace-nowrap pointer-events-none">
          河水深浅随你的心而变：<span className="text-sky-200">信心+盼望</span> 越大水越浅，<span className="text-rose-300">惧怕+疑惑+绝望</span> 越大水越深。<br/>当前：{depthCN}（用右下角「抉择」选择仰望对岸或盯着波涛）
        </div>
      </Html>

      <CompanionParty anchors={[[-2.4, 0, 6.5], [2.4, 0, 6.5]]} onTalk={() => showToast('盼望在你身边说：“要刚强，不要怕，那托住我们的，水深也夺不去。”')} />

      <hemisphereLight args={['#9fb4c8', '#15202a', 0.5]} />
      <Player start={[0, 0, 8]} />
    </group>
  )
}
