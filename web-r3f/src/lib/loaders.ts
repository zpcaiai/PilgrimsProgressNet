import * as THREE from 'three'
// three-stdlib's KTX2Loader is the one drei's GLTFLoader expects (type-compatible).
import { KTX2Loader } from 'three-stdlib'

/**
 * Self-contained asset-loader paths (P2 #9 / #11). The Draco decoder and the Basis/KTX2
 * transcoder are vendored into /public (copied from three/examples) so GLB hero props
 * with Draco-compressed geometry and KTX2-compressed textures load with no CDN and no
 * extra build step. Drop a .glb into /public/models and point a <ModelProp src> at it.
 */
export const DRACO_PATH = '/draco/'
export const KTX2_PATH = '/basis/'

let _ktx2: KTX2Loader | null = null

/** Shared KTX2 (Basis) texture loader, transcoder support detected against the renderer. */
export function getKTX2(gl: THREE.WebGLRenderer): KTX2Loader {
  if (!_ktx2) _ktx2 = new KTX2Loader().setTranscoderPath(KTX2_PATH)
  _ktx2.detectSupport(gl)
  return _ktx2
}
