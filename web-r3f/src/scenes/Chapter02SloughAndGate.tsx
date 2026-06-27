import { Html } from '@react-three/drei'
import { Chapel } from '../components/three/Chapel'
import { NPCMarker } from '../components/three/NPCMarker'
import { Player } from '../components/three/Player'
import { NaturalGround } from '../components/three/NaturalGround'
import { Water } from '../components/three/Water'
import { ModelProp } from '../components/three/ModelProp'
import { Rock, GrassClump } from '../components/three/NatureKit'

// Real generated hero model (tools/gen_models/build_props.py). Set to undefined to
// fall back to the procedural gate below.
const WICKET_GATE_SRC: string | undefined = '/models/wicket_gate.glb'
import { getChapelById } from '../lib/content'
import { useUiStore } from '../store/uiStore'

function Mire() {
  // A murky sunken pool with scattered mud mounds and a few stepping stones.
  return (
    <group>
      {/* wet, reflective mire surface (real water — reflections on desktop) */}
      <Water size={[26, 22]} position={[0, -0.18, -16]} color="#222a1b" flow={[0.009, 0.02]} repeat={[4, 3]} mirror={0.45} opacity={0.9} rippleScale={0.22} />
      {[[-6, -12], [4, -14], [-3, -18], [6, -20], [-7, -22], [2, -10]].map(([x, z], i) => (
        <mesh key={i} position={[x, -0.12, z]} scale={[1.6, 0.4, 1.6]} castShadow>
          <sphereGeometry args={[1, 12, 10]} />
          <meshStandardMaterial color="#2e2a1a" roughness={0.95} />
        </mesh>
      ))}
      {[[-1, -10], [0.5, -13], [-0.5, -16], [1, -19], [0, -22]].map(([x, z], i) => (
        <mesh key={`s${i}`} position={[x, 0.05, z]} castShadow receiveShadow>
          <cylinderGeometry args={[0.7, 0.82, 0.3, 12]} />
          <meshStandardMaterial color="#7c7666" roughness={0.55} metalness={0.05} />
        </mesh>
      ))}
      {/* reeds + rushes along the mire banks */}
      {[[-9, -12], [-8.5, -19], [8.5, -13], [9.5, -21], [-5, -24], [6.5, -9], [-10, -16]].map(([x, z], i) => (
        <GrassClump key={`r${i}`} position={[x, 0, z]} color="#4c5a30" blades={6} scale={1.5} />
      ))}
      <Rock position={[-10.5, 0, -10]} scale={0.8} seed={4} color="#5a564a" />
      <Rock position={[10, 0, -24]} scale={0.95} seed={9} color="#565246" />
    </group>
  )
}

/** A higher-fidelity procedural wicket gate: stone posts with base + capital, an arched
 *  lintel + keystone, and a studded, iron-banded oak door. Acts as the procedural
 *  fallback for the GLB hero-prop slot. */
function GateStructure() {
  const stone = '#8a8478'
  const wood = '#3c3022'
  const iron = '#2a2622'
  return (
    <group>
      {[-1.7, 1.7].map((x) => (
        <group key={x} position={[x, 0, 0]}>
          <mesh position={[0, 0.3, 0]} castShadow receiveShadow><boxGeometry args={[1, 0.6, 1]} /><meshStandardMaterial color={stone} roughness={0.95} metalness={0} /></mesh>
          <mesh position={[0, 2.3, 0]} castShadow receiveShadow><cylinderGeometry args={[0.34, 0.38, 3.6, 12]} /><meshStandardMaterial color={stone} roughness={0.95} metalness={0} /></mesh>
          <mesh position={[0, 4.2, 0]} castShadow receiveShadow><boxGeometry args={[0.9, 0.4, 0.9]} /><meshStandardMaterial color={stone} roughness={0.92} metalness={0} /></mesh>
          {/* a lantern on each post */}
          <mesh position={[0, 4.65, 0]}><sphereGeometry args={[0.16, 12, 12]} /><meshStandardMaterial color="#fff0b0" emissive="#ffcf6a" emissiveIntensity={1.6} /></mesh>
          <pointLight position={[0, 4.7, 0.2]} intensity={5} distance={10} color="#ffe6a0" />
        </group>
      ))}
      {/* arched stone lintel + keystone */}
      <mesh position={[0, 4.4, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
        <torusGeometry args={[1.7, 0.32, 10, 24, Math.PI]} />
        <meshStandardMaterial color={stone} roughness={0.93} metalness={0} />
      </mesh>
      <mesh position={[0, 6.1, 0]} castShadow><boxGeometry args={[0.5, 0.6, 0.7]} /><meshStandardMaterial color="#9a9488" roughness={0.9} /></mesh>
      {/* the oak door with iron bands, studs and a ring handle */}
      <mesh position={[0, 1.9, 0]} castShadow receiveShadow><boxGeometry args={[2.5, 3.7, 0.28]} /><meshStandardMaterial color={wood} roughness={0.85} metalness={0} /></mesh>
      {[1.1, 2.7].map((y) => (
        <mesh key={y} position={[0, y, 0.16]}><boxGeometry args={[2.5, 0.18, 0.05]} /><meshStandardMaterial color={iron} roughness={0.6} metalness={0.5} /></mesh>
      ))}
      {[-0.9, -0.3, 0.3, 0.9].map((x) =>
        [1.1, 2.7].map((y) => (
          <mesh key={`${x}-${y}`} position={[x, y, 0.2]}><sphereGeometry args={[0.06, 8, 8]} /><meshStandardMaterial color={iron} roughness={0.5} metalness={0.6} /></mesh>
        )),
      )}
      <mesh position={[0.7, 1.9, 0.22]} rotation={[Math.PI / 2, 0, 0]}><torusGeometry args={[0.16, 0.03, 8, 16]} /><meshStandardMaterial color={iron} roughness={0.5} metalness={0.6} /></mesh>
    </group>
  )
}

function WicketGate({ onTalk }: { onTalk: () => void }) {
  return (
    <group position={[0, 0, -34]}>
      {/* hero-prop slot: GLB if provided, else the procedural gate */}
      <ModelProp src={WICKET_GATE_SRC} fallback={<GateStructure />} />
      {/* warm light spilling through the open gate */}
      <pointLight position={[0, 3, 3]} intensity={14} distance={22} color="#ffe6a0" />
      <Html center position={[0, 6.7, 0]} distanceFactor={18}>
        <div className="px-2 py-0.5 text-xs bg-black/65 rounded whitespace-nowrap pointer-events-none">窄门 · Wicket Gate</div>
      </Html>
      <mesh position={[3.2, 1.2, 0]} onClick={(e) => { e.stopPropagation(); onTalk() }}
        onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
        <capsuleGeometry args={[0.3, 0.9, 4, 8]} /><meshStandardMaterial color="#caa86a" />
      </mesh>
    </group>
  )
}

export function Chapter02SloughAndGate() {
  const openDialogue = useUiStore((s) => s.openDialogue)
  const openChapel = useUiStore((s) => s.openChapel)
  const chapel = getChapelById('chapel_slough_sunken')

  return (
    <group>
      <fog attach="fog" args={['#20231c', 18, 80]} />
      <NaturalGround detail size={[70, 90]} color="#39402c" />
      {/* path */}
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, -12]} receiveShadow>
        <planeGeometry args={[4.5, 70]} />
        <meshStandardMaterial color="#4a4636" roughness={1} metalness={0} />
      </mesh>

      <Mire />
      <WicketGate onTalk={() => openDialogue('dialogue_goodwill_gate')} />

      {chapel && <Chapel data={chapel} onInteract={(c) => openChapel(c.id)} />}

      <NPCMarker name="Help 帮助" color="#3a6a8a" position={[2.5, 0, -16]} onTalk={() => openDialogue('dialogue_help_rescue')} />
      <NPCMarker name="Goodwill 善意" color="#caa86a" position={[3.2, 0, -34]} onTalk={() => openDialogue('dialogue_goodwill_gate')} />
      <NPCMarker name="Pliable 易迁(折返)" color="#6a8a5a" position={[-3.5, 0, 4]} onTalk={() => openDialogue('dialogue_pliable_join')} />

      <hemisphereLight args={['#8a93b0', '#241f1a', 0.4]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}
