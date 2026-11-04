import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import tokens from '../../../design/tokens.json'
import { AudioWaveform } from './StudioComponents'
import { designVariables, formatStudioTime } from './tokens'

afterEach(cleanup)
function luminance(hex: string) {
  const channels = [1, 3, 5].map((index) => parseInt(hex.slice(index, index + 2), 16) / 255)
    .map((value) => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
  return channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722
}
const contrast = (first: string, second: string) => (Math.max(luminance(first), luminance(second)) + .05) / (Math.min(luminance(first), luminance(second)) + .05)

describe('shared Ringify 2.0 design contract', () => {
  it('maps every semantic color from the single token source into CSS properties', () => {
    for (const mode of ['light', 'dark'] as const) for (const [role, value] of Object.entries(tokens.colors[mode])) {
      expect(designVariables).toHaveProperty(`--r-${mode}-${role}`, value)
    }
    expect(designVariables).toHaveProperty('--r-tap', '44px')
  })
  it.each(['light', 'dark'] as const)('%s normal text/accent/status pairs meet 4.5:1 on intended opaque surfaces', (mode) => {
    const colors = tokens.colors[mode]
    for (const foreground of ['text', 'secondary', 'tertiary', 'success', 'danger'] as const) {
      for (const background of ['background', 'surface'] as const) expect(contrast(colors[foreground], colors[background])).toBeGreaterThanOrEqual(4.5)
    }
    expect(contrast(colors.accent, colors.accentSoft)).toBeGreaterThanOrEqual(4.5)
  })
  it('keeps primary action text contrast and all type sizes within the documented contract', () => {
    expect(contrast(tokens.colors.onAction, tokens.colors.action)).toBeGreaterThanOrEqual(4.5)
    for (const style of Object.values(tokens.typography)) if (typeof style !== 'string') expect(style.size).toBeGreaterThanOrEqual(11)
  })
  it('rounds display timecodes without modifying audio selection values', () => {
    expect(formatStudioTime(2.4)).toBe('0:02.4')
    expect(formatStudioTime(59.96)).toBe('1:00.0')
    expect(formatStudioTime(Number.NaN)).toBe('0:00.0')
    expect(formatStudioTime(-1)).toBe('0:00.0')
  })
  it('uses matching rounded accessible timecodes on the actual waveform adapter', () => {
    render(<AudioWaveform peaks={[.1,.5,.9]} duration={24} start={2.4} end={20.8} editable />)
    expect(screen.getByRole('slider', { name:'Kesim başlangıcı' })).toHaveAttribute('aria-valuenow','2.4')
    expect(screen.getByRole('slider', { name:'Kesim başlangıcı' })).toHaveAttribute('aria-valuetext','0:02.4')
  })
})
