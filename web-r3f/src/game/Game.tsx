import { Suspense, useEffect } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls, Environment, Lightformer, SoftShadows } from '@react-three/drei'
import { EffectComposer, SSAO, Bloom, SMAA, Vignette } from '@react-three/postprocessing'
import { BlendFunction } from 'postprocessing'
import { SceneRouter } from '../scenes/SceneRouter'
import { FaithHUD } from '../components/FaithHUD'
import { ChapterObjectivePanel } from '../components/ChapterObjectivePanel'
import { DialoguePanel } from '../components/DialoguePanel'
import { ChapelPanel } from '../components/ChapelPanel'
import { StatusStrip } from '../components/StatusStrip'
import { InventoryPanel } from '../components/InventoryPanel'
import { SpiritualChoiceModal } from '../components/SpiritualChoiceModal'
import { RepentanceModal } from '../components/RepentanceModal'
import { TemptationBanner } from '../components/TemptationBanner'
import { EndingReview } from '../components/EndingReview'
import { TouchControls } from '../components/TouchControls'
import { CombatOverlay } from '../components/CombatOverlay'
import { SceneFx } from '../components/three/SceneFx'
import { AutoSurfaceDetail } from '../components/three/AutoSurfaceDetail'
import { ColorGrade, gradeFor } from '../lib/colorGrade'
import { DIALOGUES } from '../data/dialogues'
import { useUiStore } from '../store/uiStore'
import { useGameStore } from '../store/gameStore'
import { useAudioStore } from '../store/audioStore'
import { audio } from '../systems/audio/AudioEngine'
import { useSceneAudio } from '../systems/audio/sceneAudio'
import { getChapterById } from '../lib/content'
import { getChapterFlow } from '../lib/chapterFlow'
import { getAvailableChoices } from '../systems/spiritualChoiceSystem'

export function Game({ onExitToMenu }: { onExitToMenu: () => void }) {
  const ui = useUiStore()
  const gs = useGameStore((s) => s.gameState)
  const completeChapter = useGameStore((s) => s.completeChapter)
  const goTo = useGameStore((s) => s.goTo)
  const flags = gs.storyFlags
  const sceneId = gs.player.currentSceneId
  const chapter = getChapterById(gs.player.currentChapterId)
  const flow = getChapterFlow(gs.player.currentChapterId)
  const muted = useAudioStore((s) => s.muted)
  const toggleMute = useAudioStore((s) => s.toggleMute)

  useSceneAudio(sceneId)

  // Unlock the AudioContext on the first interaction (browser autoplay policy).
  useEffect(() => {
    const unlock = () => audio.resume()
    window.addEventListener('pointerdown', unlock, { once: true })
    window.addEventListener('keydown', unlock, { once: true })
    return () => { window.removeEventListener('pointerdown', unlock); window.removeEventListener('keydown', unlock) }
  }, [])

  useEffect(() => {
    if (!ui.toast) return
    audio.sfx('chime')
    const t = setTimeout(() => ui.clearToast(), 2600)
    return () => clearTimeout(t)
  }, [ui.toast])

  const objectives = flow ? flow.objectives(gs) : []
  const canAdvance = !!flow && flow.canAdvance(gs)
  const availableChoices = getAvailableChoices(gs, sceneId)
  const anyOverlay = ui.activeDialogueId || ui.activeChapelId || ui.activeChoiceId || ui.activeRepentanceId || ui.inventoryOpen

  const advance = () => {
    if (!flow?.next) return
    audio.sfx('whoosh')
    completeChapter(gs.player.currentChapterId, flow.next.chapterId)
    goTo(flow.next.chapterId, flow.next.sceneId)
  }

  return (
    <div className="relative h-full w-full">
      <Canvas
        shadows
        dpr={[1, 1.75]}
        gl={{ antialias: false, powerPreference: 'high-performance', toneMappingExposure: 1.08 }}
        camera={{ position: [0, 10, 16], fov: 55 }}
      >
        <color attach="background" args={['#1a1612']} />
        {/* Global soft (area-style) shadows for every scene. */}
        <SoftShadows size={26} samples={10} focus={0.85} />
        <Suspense fallback={null}>
          {/* Sky/ambient fill + a real shadow-casting sun. */}
          <hemisphereLight args={['#9fb0c8', '#2a241c', 0.35]} />
          <directionalLight
            position={[14, 24, 10]}
            intensity={1.7}
            color="#ffe6c4"
            castShadow
            shadow-mapSize={[2048, 2048]}
            shadow-bias={-0.0004}
            shadow-normalBias={0.02}
          >
            <orthographicCamera attach="shadow-camera" args={[-44, 44, 44, -44, 0.5, 100]} />
          </directionalLight>
          {/* Procedural image-based lighting (no network) — gives metals, water and
              cloth believable ambient reflections; only sets `environment`, not the
              background, so each scene keeps its own GradientSky. */}
          <Environment resolution={256} frames={1}>
            <Lightformer intensity={1.3} color="#fff3df" position={[0, 6, -6]} scale={[12, 12, 1]} />
            <Lightformer intensity={0.7} color="#bcd2ff" position={[-7, 4, 4]} scale={[8, 8, 1]} />
            <Lightformer intensity={0.5} color="#caa86a" position={[7, 3, 3]} scale={[6, 6, 1]} />
            <Lightformer intensity={0.35} color="#2a2620" position={[0, -5, 0]} scale={[18, 18, 1]} rotation={[Math.PI / 2, 0, 0]} />
          </Environment>
          <SceneFx sceneId={sceneId} />
          <SceneRouter sceneId={sceneId} />
          <AutoSurfaceDetail sceneId={sceneId} />
          <OrbitControls maxPolarAngle={Math.PI / 2.1} minDistance={6} maxDistance={40} target={[0, 1, -6]} />
          {/* Post: ambient occlusion (grounds objects), gentle bloom on emissives,
              vignette and SMAA antialiasing — the bulk of the "real world" feel. */}
          <EffectComposer enableNormalPass multisampling={0}>
            <SSAO
              blendFunction={BlendFunction.MULTIPLY}
              samples={16}
              rings={4}
              radius={0.22}
              intensity={7}
              luminanceInfluence={0.5}
              worldDistanceThreshold={40}
              worldDistanceFalloff={8}
              worldProximityThreshold={0.5}
              worldProximityFalloff={0.1}
            />
            <Bloom intensity={0.5} luminanceThreshold={0.85} luminanceSmoothing={0.2} mipmapBlur />
            <ColorGrade key={sceneId} args={[gradeFor(sceneId)]} />
            <Vignette offset={0.22} darkness={0.55} />
            <SMAA />
          </EffectComposer>
        </Suspense>
      </Canvas>

      <FaithHUD />
      <StatusStrip />
      <ChapterObjectivePanel chapterTitle={`第 ${chapter?.order} 章 · ${chapter?.titleCN ?? ''}`} objectives={objectives} />

      <TemptationBanner sceneId={sceneId} />

      <div className="fixed bottom-3 left-1/2 -translate-x-1/2 text-[11px] sm:text-xs opacity-60 text-center pointer-events-none px-2">
        点击 NPC / 小教堂 / 十字架 · WASD 或左下摇杆移动 · 拖动转视角
      </div>

      {sceneId === 'city_of_destruction' && !flags['read_warning_scroll'] && !anyOverlay && (
        <button
          className="fixed bottom-16 left-1/2 -translate-x-1/2 px-4 py-2 bg-amber-500/30 hover:bg-amber-500/50 rounded-lg"
          onClick={() => ui.openDialogue('dialogue_warning_scroll')}
        >
          [E] 阅读手中的书卷
        </button>
      )}

      {canAdvance && (
        <button
          className="fixed top-4 left-1/2 -translate-x-1/2 px-5 py-2 bg-emerald-500/40 hover:bg-emerald-500/60 rounded-lg font-bold animate-pulse"
          onClick={advance}
        >
          {flow?.advanceLabel} ▸
        </button>
      )}

      <div className="fixed bottom-4 right-4 flex gap-2">
        {availableChoices.length > 0 && (
          <button className="px-3 py-2 bg-indigo-500/30 hover:bg-indigo-500/50 rounded-lg text-sm" onClick={() => { audio.sfx('click'); ui.openChoice(availableChoices[0].id) }}>抉择</button>
        )}
        <button className="px-3 py-2 bg-amber-500/20 hover:bg-amber-500/40 rounded-lg text-sm" onClick={() => { audio.sfx('click'); ui.openRepentance('repent_chapel_general') }}>悔改</button>
        <button className="px-3 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-sm" onClick={() => { audio.sfx('click'); ui.openInventory() }}>行囊</button>
        <button className="px-3 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-sm" title={muted ? '取消静音' : '静音'} onClick={() => toggleMute()}>{muted ? '🔇' : '🔊'}</button>
        <button className="px-3 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-sm" onClick={onExitToMenu}>≡ 菜单</button>
      </div>

      {ui.toast && (
        <div className="fixed bottom-28 left-1/2 -translate-x-1/2 px-4 py-2 bg-black/80 border border-white/15 rounded-lg text-sm max-w-[80vw] text-center">
          {ui.toast}
        </div>
      )}

      {ui.activeDialogueId && DIALOGUES[ui.activeDialogueId] && <DialoguePanel dialogue={DIALOGUES[ui.activeDialogueId]} onClose={ui.close} />}
      {ui.activeChapelId && <ChapelPanel chapelId={ui.activeChapelId} onClose={ui.close} />}
      {ui.activeChoiceId && <SpiritualChoiceModal choiceId={ui.activeChoiceId} onClose={ui.close} />}
      {ui.activeRepentanceId && <RepentanceModal eventId={ui.activeRepentanceId} onClose={ui.close} />}
      {ui.inventoryOpen && <InventoryPanel onClose={ui.close} />}

      {gs.storyFlags.entered_celestial_city && <EndingReview onExitToMenu={onExitToMenu} />}

      <CombatOverlay />
      <TouchControls />
    </div>
  )
}
