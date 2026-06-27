import { useEffect, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import { useGLTF, useAnimations } from '@react-three/drei'
import * as THREE from 'three'
import { playerPos } from '../../systems/playerPos'

/**
 * Optional GLB pilgrim with a baked 'Walk' animation (tools/gen_models/build_character.py).
 * The clip plays while moving and freezes when idle. Opt in via PLAYER_MODEL_SRC in
 * Player.tsx; the procedural pilgrim remains the default.
 */
export function PlayerModel({ src }: { src: string }) {
  const group = useRef<THREE.Group>(null)
  const { scene, animations } = useGLTF(src)
  const { actions, names } = useAnimations(animations, group)

  useEffect(() => {
    const a = names[0] ? actions[names[0]] : undefined
    if (a) {
      a.reset().setLoop(THREE.LoopRepeat, Infinity).play()
      a.timeScale = 0
    }
  }, [actions, names])

  useFrame(() => {
    const a = names[0] ? actions[names[0]] : undefined
    if (a) a.timeScale = playerPos.moving ? 1.2 : 0 // freeze mid-stride when standing still
  })

  return (
    <group ref={group}>
      <primitive object={scene} />
    </group>
  )
}
