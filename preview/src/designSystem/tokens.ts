import type { CSSProperties } from 'react'
import tokens from '../../../design/tokens.json'

// Values come from the shared source, not a second hand-maintained color palette.
const variables: Record<string, string | number> = {}
for (const mode of ['light', 'dark'] as const) {
  for (const [role, value] of Object.entries(tokens.colors[mode])) variables[`--r-${mode}-${role}`] = value
}
for (const [name, value] of Object.entries(tokens.spacing)) variables[`--r-space-${name}`] = `${value}px`
for (const [name, value] of Object.entries(tokens.radius)) variables[`--r-radius-${name}`] = `${value}px`
for (const [name, value] of Object.entries(tokens.typography)) {
  if (typeof value !== 'string') {
    variables[`--r-type-${name}`] = `${value.size / 16}rem`
    variables[`--r-weight-${name}`] = value.weight
    variables[`--r-leading-${name}`] = value.lineHeight
  }
}
for (const [name, value] of Object.entries(tokens.shadows)) variables[`--r-shadow-${name}`] = value
for (const [name, value] of Object.entries(tokens.motion)) variables[`--r-motion-${name}`] = `${value}ms`
for (const [name, value] of Object.entries(tokens.signature)) variables[`--r-signature-${name}`] = value
variables['--r-action'] = tokens.colors.action
variables['--r-on-action'] = tokens.colors.onAction
variables['--r-tap'] = `${tokens.accessibility.minimumTapTarget}px`
variables['--r-inset'] = `${tokens.layout.contentInset}px`
variables['--r-blur'] = `${tokens.materials.webBlur}px`
variables['--r-quick'] = `${tokens.motion.quick}ms`
variables['--r-pressed-scale'] = tokens.componentStates.pressedScale
variables['--r-disabled'] = tokens.componentStates.disabledOpacity
variables['--r-focus-width'] = `${tokens.componentStates.focusWidth}px`
variables['--r-focus-offset'] = `${tokens.componentStates.focusOffset}px`
// Versioned roles keep approved 2.0 screens unchanged until their own phase.
for (const mode of ['light', 'dark'] as const) {
  for (const [role, value] of Object.entries(tokens.appleV2.colors[mode])) variables[`--n-${mode}-${role}`] = value
}
for (const [role, value] of Object.entries(tokens.appleV2.typography)) variables[`--n-type-${role}`] = `${value / 16}rem`
for (const [role, value] of Object.entries(tokens.appleV2.radius)) variables[`--n-radius-${role}`] = `${value}px`
for (const [role, value] of Object.entries(tokens.appleV2.motion)) variables[`--n-motion-${role}`] = `${value}ms`
variables['--n-inset'] = `${tokens.appleV2.contentInset}px`
variables['--n-action'] = tokens.appleV2.action
for (const mode of ['light', 'dark'] as const) {
  for (const [role, value] of Object.entries(tokens.appleVercel.colors[mode])) variables[`--av-${mode}-${role}`] = value
}
for (const [role, value] of Object.entries(tokens.appleVercel.canvas)) variables[`--av-canvas-${role}`] = value
for (const [role, value] of Object.entries(tokens.appleVercel.typography)) variables[`--av-type-${role}`] = `${value / 16}rem`
for (const [role, value] of Object.entries(tokens.appleVercel.radius)) variables[`--av-radius-${role}`] = `${value}px`
for (const [role, value] of Object.entries(tokens.appleVercel.motion)) variables[`--av-motion-${role}`] = `${value}ms`
variables['--av-action'] = tokens.appleVercel.action
variables['--av-inset'] = `${tokens.appleVercel.contentInset}px`
variables['--av-blur'] = `${tokens.appleVercel.materials.blur}px`
export const designVariables = variables as CSSProperties

export function formatStudioTime(value: number) {
  const tenths = Math.round((Number.isFinite(value) ? Math.max(0, value) : 0) * 10)
  return `${Math.floor(tenths / 600)}:${Math.floor(tenths % 600 / 10).toString().padStart(2, '0')}.${tenths % 10}`
}
