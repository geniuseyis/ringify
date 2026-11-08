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
})
