import { describe, expect, it } from 'vitest'
import { timeAtPosition, trimBoundary } from './waveformCoordinates'
describe('zoomed timeline coordinates', () => {
  it('maps a scrolled full-width track to source seconds', () => {
    expect(timeAtPosition(250,100,600,20)).toBe(5)
    expect(timeAtPosition(250,-200,1200,20)).toBe(7.5)
    expect(timeAtPosition(-999,0,600,20)).toBe(0)
  })
  it('preserves 1–29 seconds and source bounds', () => {
    expect(trimBoundary('end',90,10,20,60)).toEqual([10,39])
    expect(trimBoundary('start',50,10,20,60)).toEqual([19,20])
    expect(trimBoundary('start',0,20,60,60)).toEqual([31,60])
  })
  it('snaps close to real source edges without quantizing interior times', () => {
    expect(trimBoundary('start',0.04,2,12,20)).toEqual([0,12])
    expect(trimBoundary('end',19.96,2,12,20)).toEqual([2,20])
    expect(trimBoundary('start',1.234,2,12,20)).toEqual([1.234,12])
  })
  it('keeps maximum duration constraints even when an edge is within snap tolerance', () => {
    expect(trimBoundary('end',59.96,30.95,50,60)[1]).toBeCloseTo(59.95)
    expect(trimBoundary('start',0.04,1,29.05,60)[0]).toBeCloseTo(0.05)
  })
  it('ignores malformed pointer coordinates instead of corrupting a selection', () => {
    for (const invalid of [NaN, Infinity, -Infinity]) expect(trimBoundary('start',invalid,2,12,20)).toEqual([2,12])
  })
  it('allows maximum duration from a fractional source start without exceeding 29 seconds', () => {
    const [start,end] = trimBoundary('end',60,3.2,12,60)
    expect(start).toBe(3.2)
    expect(end-start).toBeLessThanOrEqual(29)
    expect(end-start).toBeCloseTo(29,10)
  })
  it('keeps minimum duration valid when start plus one rounds downward', () => {
    const [start,end] = trimBoundary('end',0,0.4,12,20)
    expect(start).toBe(0.4)
    expect(end-start).toBeGreaterThanOrEqual(1)
    expect(end-start).toBeCloseTo(1,10)
  })
})
