import { describe, expect, it } from 'vitest'
import { canChangeNormalization, canCreateProject } from './proAccess'
import { annualSavings, billingDisclosure, freeProjectLimit, price, proProjectLimit } from './proOffering'

describe('pro access edge cases', () => {
  it('stops free users at the project limit', () => {
    expect(canCreateProject(freeProjectLimit - 1, false)).toBe(true)
    expect(canCreateProject(freeProjectLimit, false)).toBe(false)
  })
  it('gives pro users the larger project limit', () => {
    expect(canCreateProject(proProjectLimit - 1, true)).toBe(true)
    expect(canCreateProject(proProjectLimit, true)).toBe(false)
  })
})
