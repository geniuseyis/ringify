import { describe, expect, it } from 'vitest'
import { markerSelection, maximumAudioMarkers, validateAudioMarkers } from './audioMarkers'

const marker = (id: string, time: number, label = 'Nakarat') => ({ id, time, label })

describe('audio marker edge cases', () => {
  it('treats missing markers as an empty list', () => {
    expect(validateAudioMarkers(undefined, 10)).toEqual([])
  })
  it('sorts markers by time', () => {
    expect(validateAudioMarkers([marker('b', 5), marker('a', 1)], 10).map(m => m.id)).toEqual(['a', 'b'])
  })

  it('rejects duplicate marker ids', () => {
    expect(() => validateAudioMarkers([marker('a', 1), marker('a', 2)], 10)).toThrow()
  })

  it('rejects markers past the source duration', () => {
    expect(() => validateAudioMarkers([marker('a', 11)], 10)).toThrow()
  })
  it('rejects labels with surrounding spaces', () => {
    expect(() => validateAudioMarkers([marker('a', 1, ' Giriş ')], 10)).toThrow()
  })

  it('enforces the marker limit', () => {
    const many = Array.from({ length: maximumAudioMarkers + 1 }, (_, i) => marker(`m${i}`, 1))
    expect(() => validateAudioMarkers(many, 10)).toThrow()
  })
})
