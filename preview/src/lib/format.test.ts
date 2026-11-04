import { describe, expect, it } from 'vitest'
import { formatTime, sanitizeFileName } from './format'

describe('format utilities', () => {
  it('formats duration with monospaced-friendly tenths', () => {
    expect(formatTime(65.49)).toBe('1:05.4')
    expect(formatTime(-4)).toBe('0:00.0')
  })

  it('removes file-system reserved characters', () => {
    expect(sanitizeFileName('  Mor:Ufuk?.m4a  ')).toBe('Mor-Ufuk-.m4a')
  })
})
