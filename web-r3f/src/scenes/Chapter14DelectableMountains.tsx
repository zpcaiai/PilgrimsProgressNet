import { useMemo } from 'react'
import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { CompanionParty } from '../components/three/CompanionParty'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock, Tree, GrassClump } from '../components/three/NatureKit'
import { GrassField, FlowerField } from '../components/three/InstancedNature'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'

/** The far golden Celestial City, glimpsed from the shepherds' hills. */
function DistantCity() {
  return (
    <group position={[0, 0, -52]}>
      {[-3, -1, 1, 3].map((x, i) => (
        <mesh key={x} position={[x * 1.6, 3 + (i % 2), 0]}><boxGeometry args={[1.6, 6 + (i % 2) * 2, 1.6]} /><meshStandardMaterial color="#ffe6a0" emissive="#ffcf6a" emissiveIntensity={1.3} /></mesh>
      ))}
      <pointLight position={[0, 8, 4]} intensity={14} distance={50} color="#ffe6b0" />
      <Html center position={[0, 11, 0]} distanceFactor={30}><div className="px-2 py-0.5 text-[11px] bg-black/45 rounded whitespace-nowrap pointer-events-none">远处的天城</div></Html>
    </group>
  )
}

export function Chapter14DelectableMountains() {
  const openChapel = useUiStore((s) => s.openChapel)
  const showToast = useUiStore((s) => s.showToast)
  const applyEffects = useGameStore((s) => s.applyEffects)
  const gs = useGameStore((s) => s.gameState)
  const metShepherds = !!gs.storyFlags.met_shepherds
  const sawCity = !!gs.storyFlags.saw_celestial_city
  const awake = !!gs.storyFlags.resisted_enchanted_sleep
  const chapel = getChapelById('chapel_delectable_mountains')

  const flowers = useMemo(
    () => Array.from({ length: 22 }, () => ({ x: -8 + Math.random() * 16, z: -22 - Math.random() * 12, c: ['#e58ab0', '#d0a0e0', '#f0c060'][Math.floor(Math.random() * 3)] })),
    [],
  )

  const meetShepherds = () => {
    if (metShepherds) return
    applyEffects({ vigilance: 8, hope: 6, faith: 4 }, ['met_shepherds'], ['shepherd_map'])
    showToast('牧人（知识、经验、警醒、诚实）接待你，把标出魔睡地安全路径的「牧人地图」交给你。')
  }
  const lookThrough = () => {
    applyEffects({ hope: 12, faith: 5, despair: -6 }, ['saw_celestial_city'])
    showToast('透过牧人的望远镜，你远远望见天城的门在金光中闪耀——盼望被大大坚固。')
  }
  const stayAwake = () => {
    if (awake) return
    applyEffects({ vigilance: 10, hope: 6, worldliness: -4, fear: -4 }, ['resisted_enchanted_sleep'])
    showToast(metShepherds
      ? '你照着牧人地图，与盼望彼此提醒、一路交谈，没有在魔睡地躺下——稳稳走了过去。'
      : '你强打精神，与盼望彼此提醒，不在魔睡地的花丛中躺下沉睡。')
  }

  return (
    <group>
      <fog attach="fog" args={['#bcd6e6', 40, 110]} />
      <NaturalGround detail size={[80, 120]} color="#5a8a4a" amp={0.14} />
      {/* lush instanced meadow — thousands of swaying blades + flower speckle */}
      <GrassField count={1500} area={[60, 44]} center={[0, 0, -16]} color="#5f8a44" seed={7} />
      <FlowerField count={130} area={[42, 16]} center={[0, 0, -9]} seed={3} />
      {/* rolling green peaks */}
      {[[-12, -20, 7], [10, -26, 9], [-4, -34, 11], [14, -16, 6]].map(([x, z, h], i) => (
        <group key={i}>
          <Collider circle={[x, z, h * 0.45]} />{/* core of the peak is solid */}
          <mesh position={[x, h / 2, z]} castShadow receiveShadow><coneGeometry args={[h * 0.9, h, 6]} /><meshStandardMaterial color={i % 2 ? '#4d7d3f' : '#588a48'} roughness={0.95} metalness={0} flatShading /></mesh>
        </group>
      ))}
      {/* trees, boulders and grass on the delectable meadow */}
      <Tree position={[-9, 0, -12]} scale={1.3} leaf="#4a7a3a" />
      <Tree position={[9, 0, -14]} scale={1.4} leaf="#54883f" />
      <Tree position={[-13, 0, -22]} scale={1.1} leaf="#48733a" />
      <Rock position={[7, 0, -10]} scale={1.0} seed={51} color="#7a7466" />
      <Rock position={[-7, 0, -18]} scale={1.2} seed={52} color="#6e685c" />
      {[[-3, -12], [3, -14], [-6, -9], [6, -8], [-2, -18], [4, -20]].map(([x, z], i) => (
        <GrassClump key={`g${i}`} position={[x, 0, z]} color="#5e8a3e" scale={1.2} />
      ))}

      <DistantCity />

      {/* shepherds + their telescope */}
      <NPCMarker name={metShepherds ? '牧人们（已赠图）' : '牧人 Shepherds'} color="#7a9a5a" position={[-2.5, 0, -6]} onTalk={meetShepherds} />
      <NPCMarker name="牧人 · 诚实" color="#6a8a4a" position={[-4.5, 0, -7]} onTalk={() => showToast('诚实指着远山说：那边是错误山与小心山，务要照着地图走。')} />
      <group position={[2.6, 0, -8]} onClick={(e) => { e.stopPropagation(); lookThrough() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 0.9, 0]} castShadow><cylinderGeometry args={[0.05, 0.05, 1.8, 6]} /><meshStandardMaterial color="#4a3a2a" /></mesh>
        <mesh position={[0.1, 1.5, 0.2]} rotation={[0.5, 0, 0]} castShadow><cylinderGeometry args={[0.12, 0.16, 1, 12]} /><meshStandardMaterial color="#caa23a" metalness={0.7} roughness={0.3} /></mesh>
        <Html center position={[0, 2.3, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/55 rounded whitespace-nowrap pointer-events-none">{sawCity ? '望远镜（已望见天城）' : '用望远镜远望天城（点击）'}</div></Html>
      </group>

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      {/* Enchanted Ground — a hazy, drowsy flower field */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.04, -26]}><planeGeometry args={[20, 16]} /><meshStandardMaterial color="#7a6a86" transparent opacity={0.5} /></mesh>
      {flowers.map((fl, i) => (
        <mesh key={i} position={[fl.x, 0.25, fl.z]}><sphereGeometry args={[0.16, 8, 8]} /><meshStandardMaterial color={fl.c} emissive={fl.c} emissiveIntensity={0.3} /></mesh>
      ))}
      <Html center position={[0, 1.6, -22]} distanceFactor={20}><div className="px-2 py-0.5 text-[11px] bg-black/45 rounded whitespace-nowrap pointer-events-none">魔睡地 · 此处使人昏睡</div></Html>

      {/* stay awake & cross the Enchanted Ground */}
      <group position={[0, 0, -30]} onClick={(e) => { e.stopPropagation(); stayAwake() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <mesh position={[0, 1, 0]} castShadow><cylinderGeometry args={[0.12, 0.12, 2, 8]} /><meshStandardMaterial color="#6a5942" /></mesh>
        <mesh position={[0, 2.1, 0]}><sphereGeometry args={[0.2, 12, 12]} /><meshStandardMaterial color="#fff0c0" emissive="#ffe090" emissiveIntensity={awake ? 1.8 : 0.8} /></mesh>
        <Html center position={[0, 2.8, 0]} distanceFactor={18}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">{awake ? '✓ 警醒走过魔睡地' : '保持警醒，不在此沉睡（点击）'}</div></Html>
      </group>

      <CompanionParty onTalk={() => showToast('盼望与你一路交谈，免得你们在魔睡地睡着。')} />

      <hemisphereLight args={['#dfeecf', '#3a4a30', 0.8]} />
      <directionalLight position={[8, 16, 6]} intensity={1.0} color="#fff3d6" />
      <Player start={[0, 0, 9]} />
    </group>
  )
}
