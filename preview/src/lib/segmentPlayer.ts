import type { AudioEffects } from '../types'
import { renderSelection, type AudioSamples } from './audioProcessing'

export class SegmentPlayer {
  private source: AudioBufferSourceNode | null = null
  private rendered: AudioBuffer | null = null
  private offset = 0
  private startedAt = 0
  private generation = 0
  private looping = false
  private active = false
  private duration: number
  private sourceOffset = 0

  constructor(private readonly context: AudioContext, private readonly input: AudioSamples,
    private readonly start: number, private readonly end: number, private readonly effects: AudioEffects) {
    this.duration = end - start
  }
  get isPlaying() { return this.active }
  get sourcePosition(){ return this.sourceOffset+this.position }
  get position() {
    const elapsed = this.active ? this.context.currentTime - this.startedAt : 0
    const total = this.offset + Math.max(0, elapsed)
    return this.looping ? total % this.duration : Math.min(total, this.duration)
  }
  setLoop(loop: boolean) {
    this.offset = this.position
    this.startedAt = this.context.currentTime
    this.looping = loop
    if (this.source) this.source.loop = loop
  }
  async play() {
    if (this.active) return
    const generation = ++this.generation
    await this.context.resume()
    if (generation !== this.generation) return
    if (!this.rendered) {
      const pcm = renderSelection(this.input, this.start, this.end, this.effects)
      this.duration = pcm.duration
      this.sourceOffset = pcm.sourceOffset ?? 0
      const rendered = this.context.createBuffer(pcm.channels.length, pcm.length, pcm.sampleRate)
      pcm.channels.forEach((values, channel) => rendered.getChannelData(channel).set(values))
      this.rendered = rendered
    }
    if (this.offset >= this.duration - 1e-6) this.offset = 0
    const source = this.context.createBufferSource()
    this.source = source
    try {
      source.buffer = this.rendered
      source.loop = this.looping
      source.loopStart = 0
      source.loopEnd = this.duration
      source.connect(this.context.destination)
      source.onended = () => {
        if (this.source !== source) return
        this.detach()
        this.active = false
        this.offset = 0
      }
      this.startedAt = this.context.currentTime
      source.start(0, this.offset)
      this.active = true
    } catch (error) {
      this.active = false
      this.detach()
      throw error
    }
  }
  private detach() {
    if (!this.source) return
    this.source.onended = null
    try { this.source.stop() } catch { /* Source already finished. */ }
    this.source.disconnect()
    this.source = null
  }
  pause() {
    this.generation += 1
    this.offset = this.position
    this.active = false
    this.detach()
  }
  stop() {
    this.pause()
    this.offset = 0
  }
}
