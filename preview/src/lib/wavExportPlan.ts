import type {AudioEffects} from '../types'
import type {AudioSamples} from './audioProcessing'
import {studioSettings} from './studioEffects'
import {loopOverlapFrames} from './loopCrossfade'

export type WavBitDepth=16|24
export type WavWorkStage='processing'|'encoding'|'verifying'
export function selectionExportPlan(buffer:AudioSamples,start:number,end:number,effects:AudioEffects,bitDepth:WavBitDepth=16){
  if(![start,end,buffer.sampleRate,buffer.length].every(Number.isFinite)||!Number.isInteger(buffer.length)||buffer.length<1
    ||!Number.isInteger(buffer.sampleRate)||buffer.sampleRate<1||buffer.sampleRate>192000
    ||start<0||end-start<1-1e-8||end-start>29+1e-8||end>buffer.length/buffer.sampleRate+1e-8
    ||![1,2].includes(buffer.numberOfChannels)||![16,24].includes(bitDepth))throw Error('Invalid ringtone export selection or format')
  const first=Math.round(start*buffer.sampleRate),last=Math.min(buffer.length,Math.round(end*buffer.sampleRate)),length=last-first
  if(length<1||length*buffer.numberOfChannels*4>48*1024*1024)throw Error('Export exceeds memory limit')
  const studio=studioSettings(effects.studio)
  const channels=studio.channels==='mono'?1:studio.channels==='stereo'?2:buffer.numberOfChannels
  const outputLength=length-loopOverlapFrames(effects.loopCrossfade===undefined?0:effects.loopCrossfade,buffer.sampleRate,length)
  return {first,last,length,outputLength,duration:outputLength/buffer.sampleRate,channels,sampleRate:buffer.sampleRate,bitDepth,byteCount:44+outputLength*channels*(bitDepth/8)}
}
export type WavExportPlan=ReturnType<typeof selectionExportPlan>
export function verifySelectionWav(bytes:ArrayBuffer,plan:WavExportPlan){
  const fail=()=>{throw Error('The WAV file could not be verified.')}
  if(bytes.byteLength!==plan.byteCount||bytes.byteLength<46)fail()
  const view=new DataView(bytes),text=(offset:number,count:number)=>String.fromCharCode(...new Uint8Array(bytes,offset,count))
  if(text(0,4)!=='RIFF'||text(8,8)!=='WAVEfmt '||text(36,4)!=='data'||view.getUint32(4,true)!==bytes.byteLength-8
    ||view.getUint32(16,true)!==16||view.getUint16(20,true)!==1||view.getUint16(22,true)!==plan.channels
    ||view.getUint32(24,true)!==plan.sampleRate||view.getUint32(28,true)!==plan.sampleRate*plan.channels*plan.bitDepth/8
    ||view.getUint16(32,true)!==plan.channels*plan.bitDepth/8||view.getUint16(34,true)!==plan.bitDepth
    ||view.getUint32(40,true)!==bytes.byteLength-44)fail()
}
