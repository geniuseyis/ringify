import { describe, expect, it } from 'vitest'
import { timeAtPosition, trimBoundary } from './waveformCoordinates'
import { pinchZoom } from './waveformZoom'

describe('waveform geometry edge cases', () => {
  it('clamps pointer positions to the source', () => {
    expect(timeAtPosition(-50, 0, 100, 10)).toBe(0)
    expect(timeAtPosition(500, 0, 100, 10)).toBe(10)
  })
  it('does not divide by a zero width', () => {
    expect(Number.isFinite(timeAtPosition(5, 0, 0, 10))).toBe(true)
  })
})
