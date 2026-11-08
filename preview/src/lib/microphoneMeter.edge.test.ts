import { describe, expect, it } from 'vitest'
import { rmsLevel } from './microphoneMeter'

describe('rmsLevel', () => {
  it('reports silence for an empty buffer', () => {
    expect(rmsLevel(new Float32Array())).toBe(0)
  })
})
