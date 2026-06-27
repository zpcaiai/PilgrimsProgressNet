/**
 * Runtime quality switches (P0 performance fallback).
 *
 * The heavy cost of the surface-detail pass is the full-screen triplanar ground
 * (6 texture samples / fragment). Desktops keep it; phones & tablets auto-downgrade
 * to the 1-sample planar-UV path (identical maps), so the ground stays cheap where
 * it matters. `QUALITY.detail` is a single master kill-switch for ALL procedural
 * detail (ground + nature props + inline set-pieces) — flip it to false to return
 * to flat materials everywhere in one line.
 */
function detectMobile(): boolean {
  if (typeof window === 'undefined') return false
  const coarse =
    typeof window.matchMedia === 'function' ? window.matchMedia('(pointer: coarse)').matches : false
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent || '' : ''
  return coarse || /Mobi|Android|iPhone|iPad|iPod|Tablet/i.test(ua)
}

export const IS_MOBILE = detectMobile()

export const QUALITY = {
  /** Master switch for all procedural surface detail. */
  detail: true,
  /** Triplanar ground (6 samples) on desktop; planar UV (1 sample) on mobile. */
  triplanarGround: !IS_MOBILE,
  /** Auto-apply detail to large inline set-pieces (walls / buildings / hills). */
  autoSetPieces: true,
  /** Planar reflections (real water) — desktop only; mobile uses a cheap normal-mapped surface. */
  reflections: !IS_MOBILE,
  /** Instanced-vegetation density multiplier (mobile thins it out). */
  vegetation: IS_MOBILE ? 0.45 : 1,
}
