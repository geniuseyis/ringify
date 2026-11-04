import type { AudioSamples } from '../lib/audioProcessing'

export function audioFixture(values: number[][], sampleRate = 100): AudioBuffer {
  const channels = values.map((channel) => new Float32Array(channel))
  return { sampleRate, length: channels[0].length, duration: channels[0].length / sampleRate,
    numberOfChannels: channels.length, getChannelData: (channel: number) => channels[channel] } as AudioBuffer
}

export function emptyAudio(channels: number, length: number, rate: number): AudioBuffer {
  return audioFixture(Array.from({length:channels}, () => Array<number>(length).fill(0)), rate)
}

export class FakeAudioContext {
  currentTime = 0
  sampleRate = 100
  destination = {}
  sources: FakeSource[] = []
  resume: () => Promise<void> = async () => undefined
  createBuffer(channels: number, length: number, rate: number) { return emptyAudio(channels, length, rate) }
  createBufferSource() { const source = new FakeSource(); this.sources.push(source); return source }
}

export class FakeSource {
  buffer: AudioSamples | null = null
  loop = false
  loopStart = 0
  loopEnd = 0
  onended: (() => void) | null = null
  starts: number[] = []
  stopped = false
  connect() {}
  disconnect() {}
  start(_time: number, offset: number) { this.starts.push(offset) }
  stop() { this.stopped = true }
}
