import { describe, expect, it } from 'vitest'
import { encodeSelectionAsWav } from './audio'

describe('WAV encoder', () => {
  it('creates a non-empty PCM RIFF file for the selected interval', async () => {
    const sampleRate = 8_000
    const samples = new Float32Array(sampleRate * 2)
    samples.forEach((_, index) => { samples[index] = Math.sin(index / 8) * 0.5 })
    const buffer = {
      sampleRate,
      length: samples.length,
      numberOfChannels: 1,
      getChannelData: () => samples,
    } as unknown as AudioBuffer

    const blob = encodeSelectionAsWav(buffer, 0.25, 1.25, {
      volume: 0.8,
      fadeIn: 0.1,
      fadeOut: 0.1,
      normalize: true,
    })
    const header = new TextDecoder().decode((await blob.arrayBuffer()).slice(0, 12))
    expect(header.startsWith('RIFF')).toBe(true)
    expect(header.endsWith('WAVE')).toBe(true)
    expect(blob.type).toBe('audio/wav')
    expect(blob.size).toBe(44 + sampleRate * 2)
  })
})
