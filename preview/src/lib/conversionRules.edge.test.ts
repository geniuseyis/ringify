import { describe, expect, it } from 'vitest'
import { ConversionError, conversionLimits, validateConversionSource } from './conversionRules'

const id3 = new Uint8Array([0x49, 0x44, 0x33, 0, 0, 0, 0, 0, 0, 0, 0, 0])
const mp4 = new Uint8Array([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d])
const code = (run: () => unknown) => {
  try { run() } catch (error) { return (error as ConversionError).code }
  return null
}

describe('conversion source validation', () => {
  it('accepts an MP3 with an ID3 header', () => {
    expect(validateConversionSource('song.mp3', 100, id3)).toBe('mp3')
  })

  it('accepts an upper-case MP4 extension', () => {
    expect(validateConversionSource('CLIP.MP4', 100, mp4)).toBe('mp4')
  })

  it('rejects an extension that does not match the header', () => {
    expect(code(() => validateConversionSource('song.mp3', 100, mp4))).toBe('type')
    expect(code(() => validateConversionSource('clip.mp4', 100, id3))).toBe('type')
  })

  it('rejects empty and oversized sources', () => {
    expect(code(() => validateConversionSource('a.mp3', 0, id3))).toBe('size')
    expect(code(() => validateConversionSource('a.mp3', conversionLimits.inputBytes + 1, id3))).toBe('size')
  })
  it('accepts a source at the size limit', () => {
    expect(validateConversionSource('a.mp3', conversionLimits.inputBytes, id3)).toBe('mp3')
  })
})
