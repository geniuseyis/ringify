import { afterEach, describe, expect, it, vi } from 'vitest'
import { loadProjects, loadSettings } from './storage'
afterEach(() => { vi.restoreAllMocks(); localStorage.clear() })
describe('legacy settings and metadata validation', () => {
  it('uses valid defaults for damaged preferences and rejects malformed project summaries', () => {
    localStorage.setItem('ringify.settings.v1',JSON.stringify({theme:'invalid',language:'unknown'}))
    localStorage.setItem('ringify.projects.v1',JSON.stringify([{id:'bad',name:'Missing audio fields'}]))
    expect(loadSettings().theme).toBe('system')
    expect(loadSettings().language).toBe('tr')
    expect(loadProjects()).toEqual([])
  })
  it('can launch when localStorage is denied so IndexedDB recovery remains possible', () => {
    vi.spyOn(Storage.prototype,'getItem').mockImplementation(() => {throw new DOMException('Denied','SecurityError')})
    expect(loadSettings().theme).toBe('system')
  })
})
