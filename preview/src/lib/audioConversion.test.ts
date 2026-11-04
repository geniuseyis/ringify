import {afterEach,describe,expect,it,vi} from 'vitest'
import {abortable,convertToWav,encodeConversionWav,conversionLimits,validateConversionAudio,validateConversionSource,verifyConversionWav,type ConversionDependencies} from './audioConversion'
import {encodePCMAsWav,type AudioSamples} from './audioProcessing'
const mp3=()=>new File([new Uint8Array([0x49,0x44,0x33,4,0,0,0,0,0,0])],'original.mp3',{type:'audio/mpeg'})
const fixture=(duration=1,channels=1):AudioSamples=>({sampleRate:8000,length:8000*duration,numberOfChannels:channels,getChannelData:()=>new Float32Array(8000*duration).fill(.25)})
function dependencies(audio=fixture()):ConversionDependencies{return {probe:vi.fn().mockResolvedValue(undefined),decode:vi.fn().mockResolvedValue(audio),encode:vi.fn(async()=>encodePCMAsWav({sampleRate:audio.sampleRate,length:audio.length,duration:audio.length/audio.sampleRate,channels:Array.from({length:audio.numberOfChannels},(_,i)=>audio.getChannelData(i)),appliedGain:1}).arrayBuffer())}}
describe('Conversion contracts and actual WAV verification',()=>{
 afterEach(()=>vi.unstubAllGlobals())
 it('terminates a pending encoder worker on cancellation without touching source buffers',async()=>{
  const terminate=vi.fn(),post=vi.fn()
  class TestWorker {onmessage=null;onerror=null;terminate=terminate;postMessage=post}
  vi.stubGlobal('Worker',TestWorker)
  const source=new Float32Array(8000).fill(.25),audio={...fixture(),getChannelData:()=>source},controller=new AbortController()
  const work=encodeConversionWav(audio,controller.signal)
  expect(post).toHaveBeenCalledOnce()
  const sent=post.mock.calls[0][0].channels[0] as Float32Array
  expect(sent).not.toBe(source);expect(sent[0]).toBe(.25)
  controller.abort();await expect(work).rejects.toMatchObject({name:'AbortError'});expect(terminate).toHaveBeenCalledOnce()
  expect(source[0]).toBe(.25)
 })
 it('requires both an allowed extension and matching MP3/MP4 container header',()=>{
  expect(validateConversionSource('tone.MP3',100,new Uint8Array([255,251,144,192]))).toBe('mp3')
  expect(validateConversionSource('video.mp4',100,new Uint8Array([0,0,0,24,102,116,121,112,105,115,111,109]))).toBe('mp4')
  expect(()=>validateConversionSource('fake.mp3',100,new TextEncoder().encode('RIFFWAVE'))).toThrow()
  expect(()=>validateConversionSource('tone.wav',100,new Uint8Array([255,251,144,192]))).toThrow()
 })
 it.each([0,NaN,Infinity,conversionLimits.inputBytes+1])('rejects invalid or oversized input %s before decode',size=>{expect(()=>validateConversionSource('x.mp3',size,new Uint8Array([73,68,51]))).toThrow()})
 it('permits the full 60 second file independently of 29 second ringtone selection',async()=>{
  const audio=fixture(60,2),deps=dependencies(audio),stage=vi.fn(),source=mp3(),before=await source.arrayBuffer()
  const result=await convertToWav(source,new AbortController().signal,stage,deps)
  expect(result.duration).toBe(60);expect(result.blob.size).toBe(44+audio.length*4)
  expect(await source.arrayBuffer()).toEqual(before)
  expect(stage.mock.calls.flat()).toEqual(['reading','decoding','encoding','verifying'])
  verifyConversionWav(await result.blob.arrayBuffer(),audio)
 })
 it.each([{...fixture(),sampleRate:NaN},{...fixture(),length:0},{...fixture(),numberOfChannels:3},fixture(121),{...fixture(),length:48*1024*1024,sampleRate:96000}])('rejects invalid decoded PCM without allocating output',audio=>expect(()=>validateConversionAudio(audio)).toThrow())
 it('refuses a corrupted WAV and does not report success',async()=>{
  const deps=dependencies();vi.mocked(deps.encode).mockResolvedValue(new ArrayBuffer(44))
  await expect(convertToWav(mp3(),new AbortController().signal,vi.fn(),deps)).rejects.toThrow('verification')
 })
 it('verifies codec/channel/rate/frame metadata, not only RIFF magic',async()=>{
  const audio=fixture(),bytes=await dependencies(audio).encode(audio,new AbortController().signal)
  new DataView(bytes).setUint16(20,3,true)
  expect(()=>verifyConversionWav(bytes,audio)).toThrow('verification')
 })
 it('abort before the start never invokes a media decoder',async()=>{
  const controller=new AbortController(),deps=dependencies();controller.abort()
  await expect(convertToWav(mp3(),controller.signal,vi.fn(),deps)).rejects.toMatchObject({name:'AbortError'})
  expect(deps.probe).not.toHaveBeenCalled();expect(deps.decode).not.toHaveBeenCalled()
 })
 it('cancels a pending decode and never starts encoding its late result',async()=>{
  const deps=dependencies(),controller=new AbortController();let release!:(audio:AudioSamples)=>void
  vi.mocked(deps.decode).mockImplementation(()=>new Promise(resolve=>{release=resolve}))
  const task=convertToWav(mp3(),controller.signal,()=>{},deps)
  await vi.waitFor(()=>expect(deps.decode).toHaveBeenCalledOnce());controller.abort()
  await expect(task).rejects.toMatchObject({name:'AbortError'});release(fixture());await Promise.resolve();expect(deps.encode).not.toHaveBeenCalled()
 })
 it('cleans abort listeners after normal resolution and rejects pending cancellation',async()=>{
  const controller=new AbortController(),remove=vi.spyOn(controller.signal,'removeEventListener')
  await expect(abortable(Promise.resolve(7),controller.signal)).resolves.toBe(7);expect(remove).toHaveBeenCalled()
  const pending=abortable(new Promise(()=>{}),controller.signal);controller.abort();await expect(pending).rejects.toMatchObject({name:'AbortError'})
 })
})
