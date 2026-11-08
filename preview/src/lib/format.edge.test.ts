import { describe, expect, it } from 'vitest'
import { formatFileSize, formatTime, sanitizeFileName } from './format'

describe('format edge cases', () => {
  it('treats non-finite durations as zero', () => {
    expect(formatTime(NaN)).toBe('0:00.0')
    expect(formatTime(Infinity)).toBe('0:00.0')
  })
  it('keeps minutes past an hour', () => {
    expect(formatTime(3725)).toBe('62:05.0')
  })
})
