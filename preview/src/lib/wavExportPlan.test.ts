import {describe,expect,it} from 'vitest'
import {encodePCMAsWav} from './audioProcessing'
import {selectionExportPlan,verifySelectionWav} from './wavExportPlan'
import {neutralStudio} from './studioEffects'
import {audioFixture} from '../test/audioFixtures'
const effects={volume:1,fadeIn:0,fadeOut:0,normalize:false}
describe('PCM profiles and verified output plan',()=>{
 it.each([16,24] as const)('encodes %s-bit signed little endian samples, exact size and both channel extremes',async bitDepth=>{
  const source=audioFixture([[-1,-.5,-.001,0,.001,.5,1,.99],[1,.5,.001,0,-.001,-.5,-1,-.99]],8)
  const plan=selectionExportPlan(source,0,1,effects,bitDepth)
  const bytes=await encodePCMAsWav({sampleRate:8,channels:[source.getChannelData(0),source.getChannelData(1)],length:8,duration:1,appliedGain:1},bitDepth).arrayBuffer()
  expect(bytes.byteLength).toBe(plan.byteCount);verifySelectionWav(bytes,plan)
  const view=new DataView(bytes)
  for(let i=0;i<8;i++)for(let c=0;c<2;c++){
   const offset=44+(i*2+c)*bitDepth/8
   let value=bitDepth===16?view.getInt16(offset,true):view.getUint8(offset)|(view.getUint8(offset+1)<<8)|(view.getUint8(offset+2)<<16)
   if(bitDepth===24&&value&0x800000)value|=0xff000000
   const scale=2**(bitDepth-1),decoded=value/(value<0?scale:scale-1)
   expect(Math.abs(decoded-source.getChannelData(c)[i])).toBeLessThanOrEqual(1/(scale-1))
  }
 })
 it('estimates the actual mono/stereo output after effects, not source channels',()=>{
  const source=audioFixture([Array<number>(16).fill(.1),Array<number>(16).fill(.2)],8)
  expect(selectionExportPlan(source,.5,1.5,{...effects,studio:{...neutralStudio,channels:'mono'}},24)).toMatchObject({first:4,last:12,length:8,channels:1,byteCount:68})
  const mono=audioFixture([Array<number>(16).fill(.1)],8)
  expect(selectionExportPlan(mono,0,1,{...effects,studio:{...neutralStudio,channels:'stereo'}},16)).toMatchObject({channels:2,byteCount:76})
 })
 it.each([[0,.9],[0,29.1],[-1,1],[NaN,2],[0,Infinity],[31,33]])('rejects non-ringtone selection %s–%s', (start,end)=>{
  expect(()=>selectionExportPlan(audioFixture([Array<number>(256).fill(0)],8),start,end,effects)).toThrow()
 })
 it('validates codec, actual rate/channel/precision, block alignment and byte counts',async()=>{
  const source=audioFixture([Array<number>(8).fill(.2)],8),plan=selectionExportPlan(source,0,1,effects,24)
  const clean=await encodePCMAsWav({sampleRate:8,channels:[source.getChannelData(0)],length:8,duration:1,appliedGain:1},24).arrayBuffer()
  for(const [offset,value] of [[20,3],[22,2],[24,9],[28,25],[32,2],[34,16],[40,0]]){
   const corrupt=clean.slice(0);new DataView(corrupt).setUint16(offset,value,true);expect(()=>verifySelectionWav(corrupt,plan)).toThrow(/verified/)
  }
  expect(()=>verifySelectionWav(clean.slice(0,-1),plan)).toThrow(/verified/)
 })
 it.each([NaN,Infinity,1.1])('refuses invalid PCM sample %s instead of wrapping the integer output',sample=>{
  expect(()=>encodePCMAsWav({sampleRate:8,channels:[new Float32Array([sample])],length:1,duration:.125,appliedGain:1},24)).toThrow(/PCM samples/)
 })
})
