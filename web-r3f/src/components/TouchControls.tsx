import { useEffect, useRef, useState } from 'react'
import { useInputStore } from '../store/inputStore'

const R = 52 // joystick radius (px)

/** On-screen movement joystick for touch / small screens; feeds the inputStore. */
export function TouchControls() {
  const setMove = useInputStore((s) => s.setMove)
  const [show, setShow] = useState(false)
  const [knob, setKnob] = useState({ x: 0, y: 0 })
  const baseRef = useRef<HTMLDivElement>(null)
  const activeId = useRef<number | null>(null)

  useEffect(() => {
    const check = () => setShow(window.matchMedia('(pointer: coarse)').matches || window.innerWidth < 820)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])

  if (!show) return null

  const onDown = (e: React.PointerEvent) => {
    activeId.current = e.pointerId
    ;(e.target as HTMLElement).setPointerCapture(e.pointerId)
    move(e)
  }
  const move = (e: React.PointerEvent) => {
    if (activeId.current !== e.pointerId) return
    const base = baseRef.current
    if (!base) return
    const r = base.getBoundingClientRect()
    const cx = r.left + r.width / 2
    const cy = r.top + r.height / 2
    let dx = (e.clientX - cx) / R
    let dy = (e.clientY - cy) / R
    const len = Math.hypot(dx, dy)
    if (len > 1) { dx /= len; dy /= len }
    setKnob({ x: dx * R, y: dy * R })
    setMove(dx, dy) // up (negative y) = forward (negative z) — matches Player
  }
  const onUp = (e: React.PointerEvent) => {
    if (activeId.current !== e.pointerId) return
    activeId.current = null
    setKnob({ x: 0, y: 0 })
    setMove(0, 0)
  }

  return (
    <div
      ref={baseRef}
      onPointerDown={onDown}
      onPointerMove={move}
      onPointerUp={onUp}
      onPointerCancel={onUp}
      className="fixed bottom-6 left-5 z-40 rounded-full border border-white/20 bg-white/5 backdrop-blur-sm touch-none select-none"
      style={{ width: R * 2, height: R * 2 }}
    >
      <div
        className="absolute rounded-full bg-white/30 border border-white/40"
        style={{ width: R, height: R, left: R / 2 + knob.x, top: R / 2 + knob.y, transition: activeId.current === null ? 'all 0.12s' : 'none' }}
      />
      <div className="absolute inset-0 flex items-center justify-center text-[10px] opacity-40 pointer-events-none">移动</div>
    </div>
  )
}
