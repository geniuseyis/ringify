import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import {validateImportSize,validateDecodedImport,validateWavImportHeader} from './mediaImportLimits'
import {calculatePeaks,calculatePeaksAsync} from './waveform'
import {emptyAudio,audioFixture} from '../test/audioFixtures'
let job:TestWorker
class TestWorker{onmessage:((e:{data:unknown})=>void)|null=null;onerror:(()=>void)|null=null;postMessage=vi.fn();terminate=vi.fn();constructor(){job=this}}
beforeEach(()=>vi.stubGlobal('Worker',TestWorker))
afterEach(()=>{vi.unstubAllGlobals();vi.useRealTimers()})
describe('bounded import and background waveform',()=>{
  it('rejects oversized input before reading it and invalid/oversized decoded media',()=>{
    for(const size of [0,-1,NaN,Infinity,32*1024*1024+1])expect(()=>validateImportSize(size)).toThrow()
    expect(()=>validateImportSize(32*1024*1024)).not.toThrow()
    for(const source of [emptyAudio(3,100,100),emptyAudio(1,12100,100),emptyAudio(1,99,100),{...emptyAudio(1,100,100),length:13_000_000,sampleRate:192_000}])expect(()=>validateDecodedImport(source)).toThrow()
    expect(()=>validateDecodedImport(emptyAudio(2,12000,100))).not.toThrow()
  })
  it('rejects oversized canonical WAV before decoding',()=>{
    const header=new ArrayBuffer(44),v=new DataView(header);v.setUint32(0,0x52494646);v.setUint32(8,0x57415645);v.setUint32(12,0x666d7420);v.setUint32(16,16,true);v.setUint16(22,2,true);v.setUint32(24,48000,true);v.setUint16(32,4,true);v.setUint32(36,0x64617461);v.setUint32(40,48000*4*121,true)
    expect(()=>validateWavImportHeader(header,48000)).toThrow('WAV')
    expect(()=>validateWavImportHeader(new ArrayBuffer(12),48000)).not.toThrow()
  })
  it('preserves peaks from every channel and rejects NaN instead of drawing fake data',()=>{
    expect(calculatePeaks(audioFixture([[.1,-.2,.3,0],[.8,.1,.1,-.9]]),2)).toEqual([expect.closeTo(.8),expect.closeTo(.9)])
    expect(()=>calculatePeaks(audioFixture([[NaN]]),1)).toThrow()
  })
  it('transfers copies and releases the worker on success',async()=>{
    const source=emptyAudio(1,100,100),promise=calculatePeaksAsync(source,2)
    expect(job.postMessage.mock.calls[0][0].channels[0]).not.toBe(source.getChannelData(0));job.onmessage!({data:{peaks:[.2,.5]}})
    await expect(promise).resolves.toEqual([.2,.5]);expect(job.terminate).toHaveBeenCalledOnce()
  })
  it('terminates on abort and rejects late/malformed replies',async()=>{
    const controller=new AbortController(),promise=calculatePeaksAsync(emptyAudio(1,100,100),2,controller.signal)
    controller.abort();job.onmessage!({data:{peaks:[.2,.5]}});await expect(promise).rejects.toMatchObject({name:'AbortError'});expect(job.terminate).toHaveBeenCalled()
    const bad=calculatePeaksAsync(emptyAudio(1,100,100),2);job.onmessage!({data:{peaks:[NaN]}});await expect(bad).rejects.toThrow('Invalid waveform')
  })
  it('times out an unresponsive worker and cleans up its timer',async()=>{
    vi.useFakeTimers();const promise=calculatePeaksAsync(emptyAudio(1,100,100),2),rejection=expect(promise).rejects.toThrow('timed out')
    await vi.advanceTimersByTimeAsync(20000);await rejection;expect(job.terminate).toHaveBeenCalled();expect(vi.getTimerCount()).toBe(0)
  })
})
