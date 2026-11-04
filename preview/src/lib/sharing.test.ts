import { afterEach, describe, expect, it, vi } from 'vitest'
import { shareAudioFile } from './sharing'
afterEach(() => vi.restoreAllMocks())
describe('real file sharing', () => {
  it('shares WAV bytes through the files API', async () => {
    const share = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(navigator,'share',{configurable:true,value:share})
    Object.defineProperty(navigator,'canShare',{configurable:true,value:() => true})
    await expect(shareAudioFile(new Blob([new Uint8Array([1,2])]),'Tone')).resolves.toBe('shared')
    const file = share.mock.calls[0][0].files[0] as File
    expect(file.name).toBe('Tone.wav')
    expect(file.type).toBe('audio/wav')
    expect(new Uint8Array(await file.arrayBuffer())).toEqual(new Uint8Array([1,2]))
  })
  it('downloads the actual file if file sharing is unavailable', async () => {
    Object.defineProperty(navigator,'canShare',{configurable:true,value:() => false})
    const create = vi.spyOn(URL,'createObjectURL').mockReturnValue('blob:test')
    const click = vi.spyOn(HTMLAnchorElement.prototype,'click').mockImplementation(() => undefined)
    await expect(shareAudioFile(new Blob(['wave']),'Tone')).resolves.toBe('downloaded')
    expect(create).toHaveBeenCalledWith(expect.any(Blob))
    expect(click).toHaveBeenCalledOnce()
  })
  it('treats user cancellation as cancellation, not a successful share', async () => {
    Object.defineProperty(navigator,'canShare',{configurable:true,value:() => true})
    Object.defineProperty(navigator,'share',{configurable:true,value:vi.fn().mockRejectedValue(new DOMException('Cancelled','AbortError'))})
    await expect(shareAudioFile(new Blob(['wave']),'Tone')).resolves.toBe('cancelled')
  })
})
