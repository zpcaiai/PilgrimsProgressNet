import { Suspense, Component, type ReactNode, useMemo } from 'react'
import { useThree } from '@react-three/fiber'
import { useGLTF, Clone } from '@react-three/drei'
import { DRACO_PATH, getKTX2 } from '../../lib/loaders'

type Vec3 = [number, number, number]
type Transform = { position?: Vec3; rotation?: Vec3; scale?: number | Vec3 }

function GltfModel({ src, position, rotation, scale }: { src: string } & Transform) {
  const gl = useThree((s) => s.gl)
  const extendLoader = useMemo(
    () => (loader: any) => {
      try {
        loader.setKTX2Loader?.(getKTX2(gl))
      } catch {
        /* KTX2 optional — ignore if unavailable */
      }
    },
    [gl],
  )
  const { scene } = useGLTF(src, DRACO_PATH, undefined, extendLoader)
  return <Clone object={scene} castShadow receiveShadow position={position} rotation={rotation} scale={scale} />
}

/** Renders `fallback` if a child throws (missing / failed GLB) — keeps the scene alive. */
class ModelBoundary extends Component<{ fallback: ReactNode; children: ReactNode }, { failed: boolean }> {
  state = { failed: false }
  static getDerivedStateFromError() {
    return { failed: true }
  }
  render() {
    return this.state.failed ? <>{this.props.fallback}</> : <>{this.props.children}</>
  }
}

/**
 * Hero-prop slot (P2 #9): if `src` points at a GLB it loads it (Draco + KTX2, see
 * lib/loaders.ts); otherwise — or if the load fails — it renders the procedural
 * `fallback`. This lets an artist drop real models into /public/models with zero code
 * changes, while the game still looks complete today on the procedural fallbacks.
 */
export function ModelProp({
  src,
  fallback,
  position,
  rotation,
  scale,
}: { src?: string; fallback: ReactNode } & Transform) {
  if (!src) return <>{fallback}</>
  return (
    <ModelBoundary fallback={fallback}>
      <Suspense fallback={fallback}>
        <GltfModel src={src} position={position} rotation={rotation} scale={scale} />
      </Suspense>
    </ModelBoundary>
  )
}
