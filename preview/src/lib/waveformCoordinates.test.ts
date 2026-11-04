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
})
