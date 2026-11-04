import {describe, expect, it} from 'vitest'
import {pinchZoom} from './waveformZoom'

describe('waveform pinch zoom', () => {
  it('scales from the gesture origin without accumulating each move', () => {
    expect(pinchZoom(1, 100, 150)).toBe(1.5)
    expect(pinchZoom(1, 100, 200)).toBe(2)
    expect(pinchZoom(2, 100, 125)).toBe(2.5)
  })
  it('retains existing preview limits and allows fractional zoom', () => {
    expect(pinchZoom(2, 100, 1)).toBe(1)
    expect(pinchZoom(2, 100, 900)).toBe(3)
    expect(pinchZoom(1.5, 100, 150)).toBe(2.25)
  })
  it('ignores invalid pointer distances', () => {
    for (const invalid of [NaN, Infinity, -Infinity, 0, -1]) {
      expect(pinchZoom(2, invalid, 100)).toBe(2)
      expect(pinchZoom(2, 100, invalid)).toBe(2)
    }
  })
  it('bounds malformed starting zoom and extreme finite ratios', () => {
    expect(pinchZoom(NaN, 100, 100)).toBe(1)
    expect(pinchZoom(4, 100, 100)).toBe(3)
    expect(pinchZoom(2, Number.MIN_VALUE, Number.MAX_VALUE)).toBe(3)
  })
})
