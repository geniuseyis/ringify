import { describe, expect, it } from 'vitest'
import { rmsLevel } from './microphoneMeter'

describe('rmsLevel', () => {
  it('reports silence for an empty buffer', () => {
    expect(rmsLevel(new Float32Array())).toBe(0)
  })

  it('measures a constant signal', () => {
    expect(rmsLevel(new Float32Array([0.5, -0.5, 0.5, -0.5]))).toBeCloseTo(0.5)
  })
})
