import { act, cleanup, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { startMicrophoneMeter } from '../lib/microphoneMeter'
import { useVoiceRecorder } from './useVoiceRecorder'

// Keep the real hook and real Blob/File construction. Only browser capture and
// the analyser boundary are controlled; RMS calculation is tested separately.
vi.mock('../lib/microphoneMeter', () => ({ startMicrophoneMeter: vi.fn() }))

class ControlledRecorder {
  static instances: ControlledRecorder[] = []
  static failConstructor = false
  static failStart = false
  static nextMimeType = 'audio/webm'
  mimeType = ControlledRecorder.nextMimeType
  state: RecordingState = 'inactive'
  ondataavailable: ((event: BlobEvent) => void) | null = null
  onstop: ((event: Event) => void) | null = null
  onerror: ((event: Event) => void) | null = null

  constructor(_stream: MediaStream) {
    if (ControlledRecorder.failConstructor) throw new Error('Recorder construction failed')
    ControlledRecorder.instances.push(this)
  }

  start = vi.fn((_timeslice?: number) => {
    if (ControlledRecorder.failStart) throw new Error('Recorder start failed')
    this.state = 'recording'
  })

  // The browser emits dataavailable/stop asynchronously; tests deliver them
  // explicitly so the intermediate stopping state is observable.
  stop = vi.fn(() => { this.state = 'inactive' })

  emitData(data: Blob) { this.ondataavailable?.({ data } as BlobEvent) }
  finish() {
    this.state = 'inactive'
    this.onstop?.(new Event('stop'))
  }
}

const trackStop = vi.fn()
const input = { getTracks: () => [{ stop: trackStop }] } as unknown as MediaStream
const getUserMedia = vi.fn<MediaDevices['getUserMedia']>()
const releaseMeter = vi.fn()
const createUrl = vi.fn((_blob: Blob) => 'blob:ringify-recording-test')
const revokeUrl = vi.fn((_url: string) => undefined)
let reportLevel: ((level: number) => void) | null = null

const originalMediaDevices = Object.getOwnPropertyDescriptor(navigator, 'mediaDevices')
const originalCreateUrl = Object.getOwnPropertyDescriptor(URL, 'createObjectURL')
const originalRevokeUrl = Object.getOwnPropertyDescriptor(URL, 'revokeObjectURL')

function restoreProperty(target: object, name: string, descriptor: PropertyDescriptor | undefined) {
  if (descriptor) Object.defineProperty(target, name, descriptor)
  else Reflect.deleteProperty(target, name)
}

beforeEach(() => {
  vi.clearAllMocks()
  ControlledRecorder.instances = []
  ControlledRecorder.failConstructor = false
  ControlledRecorder.failStart = false
  ControlledRecorder.nextMimeType = 'audio/webm'
  reportLevel = null
  getUserMedia.mockReset().mockResolvedValue(input)
  Object.defineProperty(navigator, 'mediaDevices', { configurable: true, value: { getUserMedia } })
  Object.defineProperty(URL, 'createObjectURL', { configurable: true, value: createUrl })
  Object.defineProperty(URL, 'revokeObjectURL', { configurable: true, value: revokeUrl })
  vi.stubGlobal('MediaRecorder', ControlledRecorder)
  vi.mocked(startMicrophoneMeter).mockImplementation((_stream, onLevel) => {
    reportLevel = onLevel
    return releaseMeter
  })
})

afterEach(() => {
  cleanup()
  vi.useRealTimers()
  restoreProperty(navigator, 'mediaDevices', originalMediaDevices)
  restoreProperty(URL, 'createObjectURL', originalCreateUrl)
  restoreProperty(URL, 'revokeObjectURL', originalRevokeUrl)
  vi.unstubAllGlobals()
})

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void
  const promise = new Promise<T>((done) => { resolve = done })
  return { promise, resolve }
}

function readFile(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error)
    reader.readAsText(file)
  })
}

describe('useVoiceRecorder capture lifecycle', () => {
  it('does not request permission or create capture resources until start is requested', () => {
    const { result, unmount } = renderHook(() => useVoiceRecorder('tr'))
    expect(result.current.status).toBe('idle')
    expect(result.current.level).toBe(0)
    expect(result.current.recordedFile).toBeNull()
    expect(getUserMedia).not.toHaveBeenCalled()
    expect(startMicrophoneMeter).not.toHaveBeenCalled()
    expect(ControlledRecorder.instances).toHaveLength(0)
    unmount()
    expect(trackStop).not.toHaveBeenCalled()
    expect(revokeUrl).not.toHaveBeenCalled()
  })

  it('gates simultaneous starts while permission is pending', async () => {
    const permission = deferred<MediaStream>()
    getUserMedia.mockReturnValueOnce(permission.promise)
    const { result } = renderHook(() => useVoiceRecorder('tr'))
    let firstStart: Promise<void> | undefined
    act(() => {
      firstStart = result.current.start()
      void result.current.start()
    })
    expect(result.current.status).toBe('requesting')
    expect(getUserMedia).toHaveBeenCalledExactlyOnceWith({ audio: true })
    await act(async () => { permission.resolve(input); await firstStart })
    expect(result.current.status).toBe('recording')
    expect(ControlledRecorder.instances).toHaveLength(1)
    expect(ControlledRecorder.instances[0].start).toHaveBeenCalledExactlyOnceWith(250)
  })

  it('releases a stream granted after unmount without constructing a recorder or meter', async () => {
    const permission = deferred<MediaStream>()
    getUserMedia.mockReturnValueOnce(permission.promise)
    const { result, unmount } = renderHook(() => useVoiceRecorder('tr'))
    let pendingStart: Promise<void> | undefined
    act(() => { pendingStart = result.current.start() })
    unmount()
    await act(async () => { permission.resolve(input); await pendingStart })
    expect(trackStop).toHaveBeenCalledOnce()
    expect(startMicrophoneMeter).not.toHaveBeenCalled()
    expect(ControlledRecorder.instances).toHaveLength(0)
    expect(createUrl).not.toHaveBeenCalled()
  })

  it('uses measured levels with finite clamping and releases recording clocks/resources', async () => {
    vi.useFakeTimers({ toFake: ['Date', 'performance', 'setInterval', 'clearInterval'] })
    const { result, unmount } = renderHook(() => useVoiceRecorder('tr'))
    await act(async () => { await result.current.start() })
    expect(startMicrophoneMeter).toHaveBeenCalledExactlyOnceWith(input, expect.any(Function))
    for (const [measured, expected] of [[0.4, 0.4], [-0.3, 0], [1.5, 1], [Number.NaN, 0], [Number.POSITIVE_INFINITY, 0]]) {
      act(() => { reportLevel!(measured) })
      expect(result.current.level).toBe(expected)
    }
    act(() => { vi.advanceTimersByTime(1250) })
    expect(result.current.seconds).toBeCloseTo(1.2)
    expect(vi.getTimerCount()).toBe(1)
    act(() => { result.current.stop() })
    expect(result.current.status).toBe('stopping')
    expect(result.current.seconds).toBeCloseTo(1.25)
    expect(vi.getTimerCount()).toBe(0)
    act(() => { reportLevel!(0.9) })
    expect(result.current.level).toBe(0)
    unmount()
    expect(releaseMeter).toHaveBeenCalledOnce()
    expect(trackStop).toHaveBeenCalledOnce()
    expect(ControlledRecorder.instances[0].ondataavailable).toBeNull()
    expect(ControlledRecorder.instances[0].onstop).toBeNull()
    expect(ControlledRecorder.instances[0].onerror).toBeNull()
    expect(vi.getTimerCount()).toBe(0)
  })

  it('combines actual captured blobs into the ready File with the recorded MIME extension', async () => {
    ControlledRecorder.nextMimeType = 'audio/mp4'
    const { result, unmount } = renderHook(() => useVoiceRecorder('tr'))
    await act(async () => { await result.current.start() })
    const capture = ControlledRecorder.instances[0]
    act(() => { result.current.stop() })
    expect(result.current.status).toBe('stopping')
    expect(result.current.recordedFile).toBeNull()
    act(() => {
      capture.emitData(new Blob(['first-'], { type: 'audio/mp4' }))
      capture.emitData(new Blob(['second'], { type: 'audio/mp4' }))
      capture.finish()
    })
    expect(result.current.status).toBe('ready')
    const file = result.current.recordedFile!
    expect(file).toBeInstanceOf(File)
    expect(file.name).toMatch(/^ringify-recording-\d+\.m4a$/)
    expect(file.type).toBe('audio/mp4')
    expect(file.size).toBe(12)
    expect(await readFile(file)).toBe('first-second')
    expect(createUrl).toHaveBeenCalledExactlyOnceWith(file)
    expect(result.current.audioUrl).toBe('blob:ringify-recording-test')
    expect(result.current.level).toBe(0)
    expect(capture.stop).toHaveBeenCalledOnce()
    expect(releaseMeter).toHaveBeenCalledOnce()
    expect(trackStop).toHaveBeenCalledOnce()
    unmount()
    expect(revokeUrl).toHaveBeenCalledExactlyOnceWith('blob:ringify-recording-test')
  })

  it('discards the ready preview, revokes its URL once and clears all user-facing state', async () => {
    const { result, unmount } = renderHook(() => useVoiceRecorder('tr'))
    await act(async () => { await result.current.start() })
    const capture = ControlledRecorder.instances[0]
    act(() => {
      result.current.stop()
      capture.emitData(new Blob(['real recorded bytes'], { type: 'audio/webm' }))
      capture.finish()
    })
    expect(result.current.recordedFile?.name).toMatch(/\.webm$/)
    act(() => { result.current.discard() })
    expect(result.current.status).toBe('idle')
    expect(result.current.audioUrl).toBeNull()
    expect(result.current.recordedFile).toBeNull()
    expect(result.current.seconds).toBe(0)
    expect(result.current.level).toBe(0)
    expect(result.current.error).toBeNull()
    expect(revokeUrl).toHaveBeenCalledExactlyOnceWith('blob:ringify-recording-test')
    unmount()
    expect(revokeUrl).toHaveBeenCalledOnce()
    expect(trackStop).toHaveBeenCalledOnce()
    expect(releaseMeter).toHaveBeenCalledOnce()
  })

  it('reports denied permission and permits a deliberate retry without retaining the old error', async () => {
    getUserMedia.mockRejectedValueOnce(new DOMException('Permission denied', 'NotAllowedError'))
    const { result } = renderHook(() => useVoiceRecorder('tr'))
    await act(async () => { await result.current.start() })
    expect(result.current.status).toBe('error')
    expect(result.current.error).toContain('Mikrofon izni reddedildi')
    expect(result.current.recordedFile).toBeNull()
    expect(ControlledRecorder.instances).toHaveLength(0)
    await act(async () => { await result.current.start() })
    expect(getUserMedia).toHaveBeenCalledTimes(2)
    expect(result.current.status).toBe('recording')
    expect(result.current.error).toBeNull()
  })

  it.each(['constructor', 'start'] as const)('cleans up granted resources when MediaRecorder %s fails', async (failure) => {
    ControlledRecorder.failConstructor = failure === 'constructor'
    ControlledRecorder.failStart = failure === 'start'
    const { result } = renderHook(() => useVoiceRecorder('en'))
    await act(async () => { await result.current.start() })
    expect(result.current.status).toBe('error')
    expect(result.current.error).toContain('The microphone could not start')
    expect(result.current.level).toBe(0)
    expect(result.current.recordedFile).toBeNull()
    expect(result.current.audioUrl).toBeNull()
    expect(releaseMeter).toHaveBeenCalledOnce()
    expect(trackStop).toHaveBeenCalledOnce()
    expect(createUrl).not.toHaveBeenCalled()
  })

  it('stops at two minutes and releases capture resources after the final data event', async () => {
    vi.useFakeTimers({toFake:['Date','performance','setInterval','clearInterval']})
    const {result}=renderHook(()=>useVoiceRecorder('tr'))
    await act(async()=>{await result.current.start()})
    act(()=>vi.advanceTimersByTime(120000))
    expect(result.current.status).toBe('stopping');expect(ControlledRecorder.instances[0].stop).toHaveBeenCalledOnce()
    act(()=>{ControlledRecorder.instances[0].emitData(new Blob(['audio'],{type:'audio/webm'}));ControlledRecorder.instances[0].finish()})
    expect(result.current.status).toBe('ready');expect(trackStop).toHaveBeenCalledOnce()
  })

  it('rejects oversized capture without creating a false ready result',async()=>{
    const {result}=renderHook(()=>useVoiceRecorder('en'))
    await act(async()=>{await result.current.start()})
    act(()=>ControlledRecorder.instances[0].emitData({size:32*1024*1024+1} as Blob))
    expect(result.current.status).toBe('error');expect(result.current.error).toContain('32 MiB')
    expect(result.current.recordedFile).toBeNull();expect(trackStop).toHaveBeenCalledOnce()
  })

  it('rejects an empty capture instead of manufacturing a successful ready File', async () => {
    const { result } = renderHook(() => useVoiceRecorder('tr'))
    await act(async () => { await result.current.start() })
    const capture = ControlledRecorder.instances[0]
    act(() => {
      result.current.stop()
      capture.emitData(new Blob([], { type: 'audio/webm' }))
      capture.finish()
    })
    expect(result.current.status).toBe('error')
    expect(result.current.error).toContain('Kayıt dosyası oluşturulamadı')
    expect(result.current.recordedFile).toBeNull()
    expect(result.current.audioUrl).toBeNull()
    expect(createUrl).not.toHaveBeenCalled()
    expect(releaseMeter).toHaveBeenCalledOnce()
    expect(trackStop).toHaveBeenCalledOnce()
  })
})
