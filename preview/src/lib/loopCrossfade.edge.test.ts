import { describe, expect, it } from 'vitest'
import { loopOverlapFrames, validateLoopCrossfade } from './loopCrossfade'

describe('loop crossfade limits', () => {
  it('allows no overlap', () => {
    expect(() => validateLoopCrossfade(0)).not.toThrow()
    expect(loopOverlapFrames(0, 44100, 1000)).toBe(0)
  })
})
