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

  it('shows plain bytes under a kilobyte', () => {
    expect(formatFileSize(999, 'en')).toBe('999 B')
  })

  it('uses decimal kilobytes and megabytes', () => {
    expect(formatFileSize(1500, 'en')).toBe('1.5 kB')
    expect(formatFileSize(2_500_000, 'en')).toBe('2.5 MB')
  })
  it('uses the Turkish decimal comma', () => {
    expect(formatFileSize(1500, 'tr')).toBe('1,5 kB')
  })
})
