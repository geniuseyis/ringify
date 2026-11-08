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

  it('ignores a non-finite trim position', () => {
    expect(trimBoundary('start', NaN, 2, 8, 20)).toEqual([2, 8])
  })

  it('snaps a trim start near the source edge', () => {
    expect(trimBoundary('start', 0.05, 2, 8, 20)).toEqual([0, 8])
  })

  it('keeps a one second minimum selection', () => {
    expect(trimBoundary('end', 2.2, 2, 8, 20)).toEqual([2, 3])
  })
  it('keeps a 29 second maximum selection', () => {
    expect(trimBoundary('end', 60, 2, 8, 90)).toEqual([2, 31])
  })
})
