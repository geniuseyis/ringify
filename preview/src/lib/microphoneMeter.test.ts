import { afterEach, describe, expect, it, vi } from 'vitest'
import { rmsLevel, startMicrophoneMeter } from './microphoneMeter'
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })
describe('microphone RMS', () => {
  it('measures silence and known amplitudes deterministically', () => {
    expect(rmsLevel(new Float32Array(2048))).toBe(0)
    expect(rmsLevel(new Float32Array([0.5,-0.5,0.5,-0.5]))).toBe(0.5)
    expect(rmsLevel(new Float32Array([1,0,-1,0]))).toBeCloseTo(Math.sqrt(0.5))
  })
  it('reads the analyser and releases the graph and timer without speaker feedback', () => {
    vi.useFakeTimers()
    const source = {connect:vi.fn(),disconnect:vi.fn()}
    const analyser = {fftSize:2048,getFloatTimeDomainData:(values:Float32Array) => values.fill(0.5),disconnect:vi.fn()}
    const context = {createMediaStreamSource:() => source,createAnalyser:() => analyser,
      resume:async () => undefined,close:vi.fn().mockResolvedValue(undefined)}
    vi.stubGlobal('AudioContext',vi.fn(function () {return context}))
    const level = vi.fn()
    const stop = startMicrophoneMeter({} as MediaStream,level)
    vi.advanceTimersByTime(80)
    expect(source.connect).toHaveBeenCalledExactlyOnceWith(analyser)
    expect(level).toHaveBeenCalledWith(0.5)
    stop()
    expect(source.disconnect).toHaveBeenCalledOnce()
    expect(context.close).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })
})
