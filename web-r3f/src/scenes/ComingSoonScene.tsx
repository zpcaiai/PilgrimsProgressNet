import { Html } from '@react-three/drei'
import { Player } from '../components/three/Player'
import { useGameStore } from '../store/gameStore'
import { getChapterById } from '../lib/content'

/** Placeholder for chapters whose bespoke scene isn't built yet (Batch 4+). */
export function ComingSoonScene() {
  const chapterId = useGameStore((s) => s.gameState.player.currentChapterId)
  const chapter = getChapterById(chapterId)
  return (
    <group>
      <fog attach="fog" args={['#1d2330', 24, 90]} />
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[80, 80]} />
        <meshStandardMaterial color="#2b3340" />
      </mesh>
      <mesh position={[0, 6, -20]}>
        <sphereGeometry args={[2.4, 20, 20]} />
        <meshStandardMaterial color="#fff0c0" emissive="#ffe6a0" emissiveIntensity={1.6} />
      </mesh>
      <pointLight position={[0, 8, -18]} intensity={20} distance={80} color="#ffe6a0" />
      <Html center position={[0, 3, -6]} distanceFactor={20}>
        <div className="px-4 py-2 bg-black/75 rounded-xl text-center whitespace-nowrap pointer-events-none">
          <div className="font-bold text-amber-200">第 {chapter?.order} 章 · {chapter?.titleCN}</div>
          <div className="text-xs opacity-70 mt-1">本章的完整场景将在后续 Batch 实现 · 可由“菜单”返回</div>
        </div>
      </Html>
      <Player start={[0, 0, 8]} />
    </group>
  )
}
