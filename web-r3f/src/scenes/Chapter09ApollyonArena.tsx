import { useCallback, useEffect, useId, useMemo, useRef, useState } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'
import { Player } from '../components/three/Player'
import { Collider } from '../components/three/Collider'
import { NaturalGround } from '../components/three/NaturalGround'
import { Rock } from '../components/three/NatureKit'
import { FireDart } from '../components/three/FireDart'
import { setObstacle, removeObstacle } from '../systems/collision'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { useCombatStore } from '../store/combatStore'
import { canFightApollyon, defeatApollyon } from '../systems/bossSystem'
import { applyMutation } from '../systems/_apply'
import { audio } from '../systems/audio/AudioEngine'
import {
  COMBAT_INIT, RESOLVE_FLOOR, RIPOSTE_MS, dartDamage, strikeDamage, telegraphMs, tierOf,
  type CombatState,
} from '../systems/combatSystem'

/** Apollyon — the bull-headed accuser, armoured and winged. `wounded` 0..1 dims and recoils him. */
function Apollyon({ wounded, defeated }: { wounded: number; defeated: boolean }) {
  const ref = useRef<THREE.Group>(null)
  const id = useId()
  useEffect(() => () => removeObstacle(id), [id])
  useFrame((state) => {
    const g = ref.current
    if (!g) return
    if (defeated) {
      g.position.y = THREE.MathUtils.lerp(g.position.y, -3.2, 0.05)
      g.rotation.x = THREE.MathUtils.lerp(g.rotation.x, 0.5, 0.05)
      removeObstacle(id)
      return
    }
    const t = state.clock.elapsedTime
    g.position.z = -14 + wounded * 3 + Math.sin(t * 1.4) * 0.15
    g.rotation.x = -wounded * 0.35
    // The accuser's body is solid — no walking through the demon.
    setObstacle(id, { kind: 'circle', x: g.position.x, z: g.position.z, r: 1.8 })
  })
  const skin = new THREE.Color('#241015').lerp(new THREE.Color('#0c0708'), wounded)
  const eye = defeated ? '#3a2a2a' : '#ff3322'
  return (
    <group ref={ref} position={[0, 0, -14]}>
      <mesh position={[0, 2.6, 0]} castShadow><boxGeometry args={[3, 5, 1.8]} /><meshStandardMaterial color={skin} metalness={0.6} roughness={0.5} /></mesh>
      <mesh position={[0, 3.0, 0.95]} castShadow><boxGeometry args={[2.2, 2.4, 0.2]} /><meshStandardMaterial color="#3a2228" metalness={0.7} roughness={0.4} /></mesh>
      <mesh position={[-1.9, 4.0, 0]} castShadow><boxGeometry args={[0.9, 1.6, 1.2]} /><meshStandardMaterial color={skin} metalness={0.6} /></mesh>
      <mesh position={[1.9, 4.0, 0]} castShadow><boxGeometry args={[0.9, 1.6, 1.2]} /><meshStandardMaterial color={skin} metalness={0.6} /></mesh>
      <mesh position={[-2.6, 4.4, -0.6]} rotation={[0, 0.5, 0.5]} castShadow><boxGeometry args={[3.4, 2.6, 0.12]} /><meshStandardMaterial color="#1a0e12" side={THREE.DoubleSide} roughness={0.9} /></mesh>
      <mesh position={[2.6, 4.4, -0.6]} rotation={[0, -0.5, -0.5]} castShadow><boxGeometry args={[3.4, 2.6, 0.12]} /><meshStandardMaterial color="#1a0e12" side={THREE.DoubleSide} roughness={0.9} /></mesh>
      <mesh position={[0, 5.9, 0.2]} castShadow><boxGeometry args={[1.8, 1.6, 1.7]} /><meshStandardMaterial color={skin} /></mesh>
      <mesh position={[0, 5.6, 1.1]} castShadow><boxGeometry args={[1.0, 0.8, 0.5]} /><meshStandardMaterial color="#2a1418" /></mesh>
      <mesh position={[-1.0, 6.6, 0.2]} rotation={[0, 0, 0.7]} castShadow><coneGeometry args={[0.28, 1.5, 8]} /><meshStandardMaterial color="#c9b89a" /></mesh>
      <mesh position={[1.0, 6.6, 0.2]} rotation={[0, 0, -0.7]} castShadow><coneGeometry args={[0.28, 1.5, 8]} /><meshStandardMaterial color="#c9b89a" /></mesh>
      <mesh position={[-0.4, 6.0, 1.15]}><sphereGeometry args={[0.16, 12, 12]} /><meshStandardMaterial color={eye} emissive={eye} emissiveIntensity={defeated ? 0.4 : 2.2} /></mesh>
      <mesh position={[0.4, 6.0, 1.15]}><sphereGeometry args={[0.16, 12, 12]} /><meshStandardMaterial color={eye} emissive={eye} emissiveIntensity={defeated ? 0.4 : 2.2} /></mesh>
      {!defeated && <pointLight position={[0, 5.5, 2]} intensity={6 - wounded * 4} distance={16} color="#ff3a2a" />}
      <Html center position={[0, 7.6, 0]} distanceFactor={22}>
        <div className="px-2 py-0.5 text-[11px] bg-black/70 rounded whitespace-nowrap pointer-events-none">
          {defeated ? '亚玻伦败退' : '亚玻伦 Apollyon · 控告者'}
        </div>
      </Html>
    </group>
  )
}

function FieryRift() {
  const embers = useMemo(
    () => Array.from({ length: 14 }, () => ({ x: (Math.random() - 0.5) * 6, z: -16 + Math.random() * 18, s: 0.06 + Math.random() * 0.1, p: Math.random() * 6 })),
    [],
  )
  const grp = useRef<THREE.Group>(null)
  useFrame((state) => {
    if (!grp.current) return
    grp.current.children.forEach((m, i) => { m.position.y = 0.2 + ((state.clock.elapsedTime * 0.6 + embers[i].p) % 4) })
  })
  return (
    <group>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.03, -7]}>
        <planeGeometry args={[3.4, 22]} /><meshStandardMaterial color="#ff5a1e" emissive="#ff6a22" emissiveIntensity={1.6} />
      </mesh>
      <group ref={grp}>
        {embers.map((e, i) => (
          <mesh key={i} position={[e.x, 0.3, e.z]}><sphereGeometry args={[e.s, 6, 6]} /><meshStandardMaterial color="#ffae5a" emissive="#ff8a3a" emissiveIntensity={2} /></mesh>
        ))}
      </group>
    </group>
  )
}

export function Chapter09ApollyonArena() {
  const openDialogue = useUiStore((s) => s.openDialogue)
  const showToast = useUiStore((s) => s.showToast)
  const mutate = useGameStore((s) => s.mutate)
  const gs = useGameStore((s) => s.gameState)
  const defeatedFlag = !!gs.storyFlags.defeated_apollyon

  const setActive = useCombatStore((s) => s.setActive)
  const setHandlers = useCombatStore((s) => s.setHandlers)
  const setStoreState = useCombatStore((s) => s.setState)

  const [combat, setCombat] = useState<CombatState>(() => (defeatedFlag ? { ...COMBAT_INIT, bossHp: 0, phase: 'won' } : COMBAT_INIT))
  const combatRef = useRef(combat); combatRef.current = combat
  const canFightRef = useRef(canFightApollyon(gs)); canFightRef.current = canFightApollyon(gs)

  // --- handlers (stable; read latest via refs) ---
  const startFight = useCallback(() => {
    if (!canFightRef.current) { showToast('没有披戴全副军装，不可迎战控告者。先回军装厅领取军装。'); return }
    audio.sfx('tempt'); setCombat({ ...COMBAT_INIT, phase: 'telegraph', volley: 1 })
  }, [showToast])
  const raiseGuard = useCallback(() => {
    audio.sfx('click'); setCombat((c) => (c.phase === 'telegraph' ? { ...c, guard: true } : c))
  }, [])
  const strike = useCallback(() => {
    const c = combatRef.current
    if (c.phase !== 'riposte') return
    audio.sfx('sword')
    const bossHp = c.bossHp - strikeDamage(c.lastBlocked)
    if (bossHp <= 0) {
      setCombat({ ...c, bossHp: 0, phase: 'won' })
      mutate((s) => defeatApollyon(s)); audio.sfx('victory')
      showToast('“我虽跌倒，却要起来！”圣灵的宝剑得胜，亚玻伦张开翅膀遁去——你靠主站立。')
    } else {
      setCombat({ ...c, bossHp, phase: 'telegraph', volley: c.volley + 1, guard: false })
    }
  }, [mutate, showToast])

  // register with the DOM combat HUD
  useEffect(() => {
    setActive(true)
    setHandlers({ onStart: startFight, onGuard: raiseGuard, onStrike: strike })
    return () => { setActive(false); setStoreState(null) }
  }, [setActive, setHandlers, setStoreState, startFight, raiseGuard, strike])
  useEffect(() => { setStoreState(combat) }, [combat, setStoreState])

  // volley timers: telegraph -> resolve -> riposte -> next volley
  useEffect(() => {
    if (combat.phase === 'telegraph') {
      const tier = tierOf(combat.bossHp)
      const id = setTimeout(() => {
        const c = combatRef.current
        const blocked = c.guard
        if (blocked) audio.sfx('shield')
        else { audio.sfx('hit'); mutate((s) => applyMutation(s, { effects: { accusation: 6, fear: 3 } })) }
        const resolve = blocked ? Math.min(100, c.resolve + 4) : Math.max(RESOLVE_FLOOR, c.resolve - dartDamage(tier))
        setCombat({ ...c, resolve, guard: false, lastBlocked: blocked, phase: 'riposte' })
        showToast(blocked ? '信德的盾挡下亚玻伦的火箭！趁势还击。' : '火箭擦过，你的心受了控告——下一波要举起信德的盾！')
      }, telegraphMs(tier))
      return () => clearTimeout(id)
    }
    if (combat.phase === 'riposte') {
      const id = setTimeout(() => {
        const c = combatRef.current
        if (c.phase === 'riposte') setCombat({ ...c, phase: 'telegraph', volley: c.volley + 1, guard: false })
      }, RIPOSTE_MS)
      return () => clearTimeout(id)
    }
  }, [combat.phase, combat.volley, combat.bossHp, mutate, showToast])

  const won = combat.phase === 'won' || defeatedFlag
  const wounded = won ? 1 : 1 - combat.bossHp / 100

  return (
    <group>
      <fog attach="fog" args={['#180a0a', 16, 70]} />
      <NaturalGround detail size={[50, 80]} color="#241414" />
      <mesh position={[-13, 7, -18]} castShadow receiveShadow><boxGeometry args={[6, 14, 56]} /><meshStandardMaterial color="#1c1012" roughness={0.95} metalness={0} /></mesh>
      <mesh position={[13, 7, -18]} castShadow receiveShadow><boxGeometry args={[6, 14, 56]} /><meshStandardMaterial color="#1c1012" roughness={0.95} metalness={0} /></mesh>
      <Collider box={[-13, -18, 6, 56]} />
      <Collider box={[13, -18, 6, 56]} />
      {/* charred boulders strewn at the cliff feet */}
      <Rock position={[-9.5, 0, -4]} scale={1.3} seed={41} color="#241818" />
      <Rock position={[9.5, 0, -10]} scale={1.6} seed={42} color="#2a1c18" />
      <Rock position={[-9.5, 0, -22]} scale={1.4} seed={43} color="#221616" />
      <Rock position={[9.5, 0, -26]} scale={1.2} seed={44} color="#2a1c18" />

      <FieryRift />
      <Apollyon wounded={wounded} defeated={won} />
      {combat.phase === 'telegraph' && <FireDart key={combat.volley} duration={telegraphMs(tierOf(combat.bossHp)) / 1000} />}

      {/* optional: hear the accusation (narrative) */}
      {!won && (
        <group position={[6.5, 0, -1]} onClick={(e) => { e.stopPropagation(); openDialogue('dialogue_apollyon_accusation') }}
          onPointerOver={() => (document.body.style.cursor = 'pointer')} onPointerOut={() => (document.body.style.cursor = 'default')}>
          <mesh position={[0, 1.1, 0]}><boxGeometry args={[0.6, 1.8, 0.1]} /><meshStandardMaterial color="#3a2a2a" /></mesh>
          <Html center position={[0, 2.2, 0]} distanceFactor={16}><div className="px-2 py-0.5 text-[11px] bg-black/60 rounded whitespace-nowrap pointer-events-none">听亚玻伦的控告</div></Html>
        </group>
      )}

      {won && (
        <>
          <pointLight position={[0, 10, -6]} intensity={16} distance={50} color="#ffe6b0" />
          <Html center position={[0, 5, -4]} distanceFactor={22}>
            <div className="px-3 py-1.5 bg-black/70 rounded-lg text-center text-amber-200 whitespace-nowrap pointer-events-none">控告者败退 · 你靠羔羊的血与所见证的道得胜</div>
          </Html>
        </>
      )}

      {!won && (
        <Html center position={[0, 0.5, 7]} distanceFactor={26}>
          <div className="px-3 py-1 bg-black/55 rounded text-[11px] text-center max-w-[260px] pointer-events-none">
            底部面板作战：火箭来时「举盾」，挡下后「挥剑」还击。挡格后的还击更重。
          </div>
        </Html>
      )}

      <hemisphereLight args={['#6a3a3a', '#100808', 0.4]} />
      <Player start={[0, 0, 9]} />
    </group>
  )
}
