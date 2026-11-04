import {describe,expect,it} from 'vitest'
import {renderSelection,encodePCMAsWav} from './audioProcessing'
import {neutralStudio,studioSettings} from './studioEffects'
import {analyzeAudio} from './audioAnalysis'
import {canChangeStudioEffects} from './proAccess'
import {audioFixture,FakeAudioContext} from '../test/audioFixtures'
import {SegmentPlayer} from './segmentPlayer'
const neutral={volume:1,fadeIn:0,fadeOut:0,normalize:false}
const tone=(frequency:number,amplitude=.05)=>audioFixture([Array.from({length:24000},(_,i)=>Math.sin(2*Math.PI*frequency*i/48000)*amplitude)],48000)
const rms=(values:Float32Array)=>Math.sqrt(values.slice(4800).reduce((sum,v)=>sum+v*v,0)/(values.length-4800))
describe('Shared advanced DSP',()=>{
 it('preserves legacy neutral PCM exactly and never changes source data',()=>{
  const input=tone(440),before=input.getChannelData(0).slice()
  expect(renderSelection(input,0,.5,{...neutral,studio:{...neutralStudio}})).toEqual(renderSelection(input,0,.5,neutral))
  renderSelection(input,0,.5,{...neutral,studio:{...neutralStudio,lowPass:1000}})
  expect(input.getChannelData(0)).toEqual(before)
 })
 it.each([['lowPass',100,8000],['highPass',8000,100]] as const)('%s passes its passband and attenuates its stopband', (filter,pass,stop)=>{
  const settings={...neutral,studio:{...neutralStudio,[filter]:1000}}
  const passing=rms(renderSelection(tone(pass),0,.5,settings).channels[0]),blocked=rms(renderSelection(tone(stop),0,.5,settings).channels[0])
  expect(passing).toBeGreaterThan(.03);expect(blocked/passing).toBeLessThan(.03)
 })
 it.each([6,-6])('peaking EQ produces the specified %s dB gain at its center',gain=>{
  const input=tone(1000),result=renderSelection(input,0,.5,{...neutral,studio:{...neutralStudio,mid:gain}})
  expect(20*Math.log10(rms(result.channels[0])/rms(input.getChannelData(0)))).toBeCloseTo(gain,2)
 })
 it('downmixes stereo by averaging and duplicates mono without fabricating width',()=>{
  const input=audioFixture([[.2,.4],[-.2,-.4]],2)
  expect([...renderSelection(input,0,1,{...neutral,studio:{...neutralStudio,channels:'mono'}}).channels[0]]).toEqual([0,0])
  const stereo=renderSelection(audioFixture([[.2,.4]],2),0,1,{...neutral,studio:{...neutralStudio,channels:'stereo'}})
  expect(stereo.channels).toHaveLength(2);expect(stereo.channels[0]).toEqual(stereo.channels[1]);expect(stereo.channels[0]).not.toBe(stereo.channels[1])
 })
 it('limits linked channels without shifting the impulse or exceeding the ceiling',()=>{
  const left=Array<number>(2000).fill(.1);left[500]=2
  const right=left.map(v=>v*.5),input=audioFixture([left,right],1000)
  const output=renderSelection(input,0,2,{...neutral,studio:{...neutralStudio,limiter:true,ceiling:.8}})
  expect(output.channels[0].reduce((p,v)=>Math.max(p,Math.abs(v)),0)).toBeLessThanOrEqual(.800001)
  expect(output.channels[0].indexOf(Math.max(...output.channels[0]))).toBe(500)
  expect(output.channels[0][500]).toBeCloseTo(.8,5);expect(output.channels[1][500]/output.channels[0][500]).toBeCloseTo(.5,5)
  expect(output.channels[0][501]).toBeLessThan(output.channels[0][1500])
 })
 it('shares the exact processed signal between SegmentPlayer and WAV export',async()=>{
  const input=tone(5000,.4),effects={...neutral,volume:1.5,fadeIn:.02,studio:{...neutralStudio,lowPass:3400,limiter:true,ceiling:.7}}
  const pcm=renderSelection(input,0,.5,effects),context=new FakeAudioContext(),player=new SegmentPlayer(context as unknown as AudioContext,input,0,.5,effects)
  await player.play();expect(context.sources[0].buffer!.getChannelData(0)).toEqual(pcm.channels[0])
  const bytes=new DataView(await encodePCMAsWav(pcm).arrayBuffer())
  for(let i=0;i<pcm.length;i+=37){const sample=bytes.getInt16(44+i*2,true);expect(Math.abs(sample/(sample<0?32768:32767)-pcm.channels[0][i])).toBeLessThan(1/32767)}
 })
 it.each([{mid:NaN},{low:13},{ceiling:1},{lowPass:-1},{highPass:500,lowPass:300},{channels:'surround'},{limiter:'yes'}])('rejects invalid advanced configuration %j',partial=>{
  expect(()=>studioSettings(partial as never)).toThrow()
 })
 it('rejects a NaN source with active filters and keeps silence finite through limiting',()=>{
  expect(()=>renderSelection(audioFixture([[0,0],[0,0],[.8,.9]],2),0,1,neutral)).toThrow(/mono/)
  expect(()=>renderSelection(audioFixture([[0,NaN]],48000),0,2/48000,{...neutral,studio:{...neutralStudio,mid:1}})).toThrow(/samples/)
  expect([...renderSelection(audioFixture([[0,0]],2),0,1,{...neutral,studio:{...neutralStudio,limiter:true}}).channels[0]]).toEqual([0,0])
 })
 it('rejects frequencies beyond the actual source Nyquist limit instead of silently moving the EQ band',()=>{
  expect(()=>renderSelection(audioFixture([Array<number>(8000).fill(.1)],8000),0,1,{...neutral,studio:{...neutralStudio,high:3}})).toThrow(/Nyquist/)
 })
})
describe('Deterministic PCM analysis',()=>{
 it('measures peak/RMS, leading and trailing silence and a valid trim suggestion',()=>{
  const values=new Float32Array(2000);values.fill(.5,500,1500)
  const result=analyzeAudio([values],1000)
  expect(result.peakDbFS).toBeCloseTo(20*Math.log10(.5));expect(result.rmsDbFS).toBeCloseTo(20*Math.log10(Math.sqrt(.125)))
  expect(result.silentRegions).toEqual([{start:0,end:.5},{start:1.5,end:2}]);expect(result.suggestion).toEqual({start:.5,end:1.5})
 })
 it('uses both channels without cancellation, avoids invalid suggestions for silence and short noise gaps',()=>{
  const signal=new Float32Array(1000).fill(.2),silent=new Float32Array(1000)
  expect(analyzeAudio([signal,signal.map(v=>-v)],1000).rmsDbFS).toBeCloseTo(20*Math.log10(.2))
  expect(analyzeAudio([silent],1000)).toMatchObject({peakDbFS:null,rmsDbFS:null,suggestion:null})
  signal.fill(0,100,300);expect(analyzeAudio([signal],1000).silentRegions).toEqual([])
 })
 it.each([[new Float32Array([NaN])],[new Float32Array()],[new Float32Array(30000)]])('rejects invalid or over-29-second analysis',samples=>expect(()=>analyzeAudio([samples],1000)).toThrow())
})
describe('Advanced feature policy',()=>{
 it('requires Pro for new settings, retains old effects and always permits removing them',()=>{
  const advanced={studio:{...neutralStudio,mid:3}}
  expect(canChangeStudioEffects({},advanced,false)).toBe(false);expect(canChangeStudioEffects({},advanced,true)).toBe(true)
  expect(canChangeStudioEffects(advanced,advanced,false)).toBe(true);expect(canChangeStudioEffects(advanced,{},false)).toBe(true)
  expect(canChangeStudioEffects(advanced,{studio:{...neutralStudio,mid:4}},false)).toBe(false)
  expect(canChangeStudioEffects({}, {studio:{...neutralStudio,mid:NaN}},true)).toBe(false)
 })
})
