import { describe, expect, it } from 'vitest'
import { loopOverlapFrames, validateLoopCrossfade } from './loopCrossfade'

describe('loop crossfade limits', () => {
  it('allows no overlap', () => {
    expect(() => validateLoopCrossfade(0)).not.toThrow()
    expect(loopOverlapFrames(0, 44100, 1000)).toBe(0)
  })

  it('rejects overlaps outside 5-250 ms', () => {
    expect(() => validateLoopCrossfade(0.004)).toThrow()
    expect(() => validateLoopCrossfade(0.251)).toThrow()
  })

  it('limits the overlap to a quarter of the selection', () => {
    expect(loopOverlapFrames(0.25, 44100, 4000)).toBe(1000)
  })

  it('rejects selections too short to overlap', () => {
    expect(() => loopOverlapFrames(0.1, 44100, 4)).toThrow()
  })
})
