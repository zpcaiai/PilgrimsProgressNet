// ---------------------------------------------------------------------------
// Batch 7 — a tiny procedural Web Audio engine. No asset files: every sound is
// synthesised, so the bundle stays small and it works offline. One-shot SFX +
// a breathing per-chapter ambient pad. Lazily unlocked on the first gesture.
// ---------------------------------------------------------------------------

export type SfxName =
  | 'click' | 'chime' | 'bell' | 'sword' | 'shield' | 'fire' | 'water'
  | 'gate' | 'victory' | 'tempt' | 'pickup' | 'hit' | 'whoosh'

export type AmbientPreset = {
  rootHz: number
  intervals: number[]   // semitone offsets stacked into the pad
  cutoff: number        // lowpass cutoff (mood: lower = darker)
  type: OscillatorType
  gain: number
}

type Ctx = AudioContext

class Engine {
  private ctx: Ctx | null = null
  private master: GainNode | null = null
  private ambientGain: GainNode | null = null
  private ambientNodes: AudioNode[] = []
  private noise: AudioBuffer | null = null
  private muted = false
  private volume = 0.6
  private currentAmbient: string | null = null

  /** Create the context (must follow a user gesture on most browsers). */
  private ensure(): Ctx | null {
    if (this.ctx) return this.ctx
    if (typeof window === 'undefined') return null
    const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!AC) return null
    const ctx = new AC()
    const master = ctx.createGain()
    master.gain.value = this.muted ? 0 : this.volume
    master.connect(ctx.destination)
    const ambientGain = ctx.createGain()
    ambientGain.gain.value = 0
    ambientGain.connect(master)
    // brown-ish noise buffer reused by several SFX
    const buf = ctx.createBuffer(1, ctx.sampleRate * 1.2, ctx.sampleRate)
    const d = buf.getChannelData(0)
    let last = 0
    for (let i = 0; i < d.length; i++) { const w = Math.random() * 2 - 1; last = (last + 0.02 * w) / 1.02; d[i] = last * 3.2 }
    this.ctx = ctx; this.master = master; this.ambientGain = ambientGain; this.noise = buf
    return ctx
  }

  resume() { const c = this.ensure(); if (c && c.state === 'suspended') void c.resume() }

  setMuted(m: boolean) {
    this.muted = m
    if (this.master && this.ctx) this.master.gain.setTargetAtTime(m ? 0 : this.volume, this.ctx.currentTime, 0.05)
  }
  isMuted() { return this.muted }

  setVolume(v: number) {
    this.volume = Math.max(0, Math.min(1, v))
    if (this.master && this.ctx && !this.muted) this.master.gain.setTargetAtTime(this.volume, this.ctx.currentTime, 0.05)
  }

  private env(node: GainNode, t: number, a: number, d: number, peak: number) {
    node.gain.setValueAtTime(0.0001, t)
    node.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a)
    node.gain.exponentialRampToValueAtTime(0.0001, t + a + d)
  }

  private tone(freq: number, type: OscillatorType, t: number, a: number, d: number, peak: number, dest?: AudioNode) {
    const c = this.ctx!; const o = c.createOscillator(); const g = c.createGain()
    o.type = type; o.frequency.value = freq
    this.env(g, t, a, d, peak)
    o.connect(g); g.connect(dest ?? this.master!)
    o.start(t); o.stop(t + a + d + 0.05)
  }

  private noiseBurst(t: number, dur: number, peak: number, filterType: BiquadFilterType, freq: number, q = 1) {
    const c = this.ctx!; const src = c.createBufferSource(); src.buffer = this.noise
    const f = c.createBiquadFilter(); f.type = filterType; f.frequency.value = freq; f.Q.value = q
    const g = c.createGain(); this.env(g, t, dur * 0.2, dur * 0.8, peak)
    src.connect(f); f.connect(g); g.connect(this.master!)
    src.start(t); src.stop(t + dur + 0.05)
  }

  /** Fire a one-shot effect. */
  sfx(name: SfxName) {
    const c = this.ensure(); if (!c || this.muted || !this.master) return
    if (c.state === 'suspended') void c.resume()
    const t = c.currentTime
    switch (name) {
      case 'click': this.tone(620, 'triangle', t, 0.005, 0.05, 0.12); break
      case 'chime': this.tone(880, 'sine', t, 0.006, 0.16, 0.14); this.tone(1320, 'sine', t + 0.02, 0.006, 0.18, 0.07); break
      case 'bell': this.tone(523.25, 'sine', t, 0.005, 1.3, 0.22); this.tone(1046.5, 'sine', t, 0.005, 1.0, 0.10); this.tone(1567.98, 'sine', t, 0.005, 0.7, 0.05); break
      case 'sword': this.noiseBurst(t, 0.22, 0.5, 'bandpass', 2600, 1.6); { const o = c.createOscillator(); const g = c.createGain(); o.type = 'sawtooth'; o.frequency.setValueAtTime(900, t); o.frequency.exponentialRampToValueAtTime(180, t + 0.2); this.env(g, t, 0.005, 0.2, 0.18); o.connect(g); g.connect(this.master); o.start(t); o.stop(t + 0.27) } break
      case 'shield': this.tone(1200, 'sine', t, 0.004, 0.18, 0.16); this.tone(1840, 'sine', t + 0.01, 0.004, 0.14, 0.09); this.noiseBurst(t, 0.06, 0.12, 'highpass', 4000); break
      case 'fire': this.noiseBurst(t, 0.5, 0.5, 'lowpass', 760, 0.8); break
      case 'water': this.noiseBurst(t, 0.6, 0.34, 'lowpass', 520, 0.7); break
      case 'whoosh': this.noiseBurst(t, 0.35, 0.3, 'bandpass', 1100, 0.7); break
      case 'gate': [0, 4, 7, 12].forEach((s, i) => this.tone(261.63 * Math.pow(2, s / 12), 'triangle', t + i * 0.06, 0.2, 1.4, 0.12)); break
      case 'victory': [0, 4, 7, 12, 16].forEach((s, i) => this.tone(392 * Math.pow(2, s / 12), 'triangle', t + i * 0.09, 0.01, 0.35, 0.14)); break
      case 'tempt': { const o = c.createOscillator(); const o2 = c.createOscillator(); const g = c.createGain(); o.type = 'sine'; o2.type = 'sine'; o.frequency.value = 196; o2.frequency.value = 277.18; this.env(g, t, 0.05, 0.6, 0.14); const lfo = c.createOscillator(); const lg = c.createGain(); lfo.frequency.value = 6; lg.gain.value = 8; lfo.connect(lg); lg.connect(o.frequency); o.connect(g); o2.connect(g); g.connect(this.master); o.start(t); o2.start(t); lfo.start(t); o.stop(t + 0.7); o2.stop(t + 0.7); lfo.stop(t + 0.7) } break
      case 'pickup': this.tone(660, 'sine', t, 0.005, 0.1, 0.13); this.tone(990, 'sine', t + 0.07, 0.005, 0.12, 0.12); break
      case 'hit': this.noiseBurst(t, 0.12, 0.4, 'lowpass', 1800); this.tone(110, 'sine', t, 0.004, 0.12, 0.2); break
    }
  }

  /** Switch the looping ambient pad (crossfaded). `key` dedupes repeat calls. */
  startAmbient(key: string, p: AmbientPreset) {
    const c = this.ensure(); if (!c || !this.ambientGain) return
    if (this.currentAmbient === key) return
    this.currentAmbient = key
    this.stopAmbientNodes()
    const out = this.ambientGain
    p.intervals.forEach((semi, i) => {
      const o = c.createOscillator(); const g = c.createGain()
      o.type = p.type; o.frequency.value = p.rootHz * Math.pow(2, semi / 12)
      o.detune.value = (i - 1) * 4
      g.gain.value = 1 / p.intervals.length
      const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = p.cutoff
      o.connect(g); g.connect(f); f.connect(out)
      o.start()
      this.ambientNodes.push(o, g, f)
    })
    // slow breathing LFO on the bus
    const lfo = c.createOscillator(); const lg = c.createGain()
    lfo.frequency.value = 0.08; lg.gain.value = p.gain * 0.4
    lfo.connect(lg); lg.connect(out.gain)
    lfo.start(); this.ambientNodes.push(lfo, lg)
    out.gain.cancelScheduledValues(c.currentTime)
    out.gain.setTargetAtTime(this.muted ? 0 : p.gain, c.currentTime, 1.2)
  }

  private stopAmbientNodes() {
    const c = this.ctx; if (!c || !this.ambientGain) return
    this.ambientGain.gain.setTargetAtTime(0, c.currentTime, 0.4)
    const nodes = this.ambientNodes; this.ambientNodes = []
    setTimeout(() => nodes.forEach((n) => { try { (n as OscillatorNode).stop?.() } catch { /* gain nodes */ } try { n.disconnect() } catch { /* ignore */ } }), 700)
  }

  stopAmbient() { this.currentAmbient = null; this.stopAmbientNodes() }
}

export const audio = new Engine()
