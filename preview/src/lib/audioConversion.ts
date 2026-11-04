import type {AudioSamples} from './audioProcessing'
import {ConversionError,conversionLimits,validateConversionAudio,validateConversionSource,verifyConversionWav,type ConversionStage} from './conversionRules'
export {ConversionError,conversionLimits,validateConversionAudio,validateConversionSource,verifyConversionWav,type ConversionStage} from './conversionRules'

export function abortable<T>(operation:Promise<T>,signal:AbortSignal):Promise<T>{
  return new Promise((resolve,reject)=>{
    const abort=()=>{signal.removeEventListener('abort',abort);reject(new DOMException('Cancelled','AbortError'))}
    if(signal.aborted){abort();return}
    signal.addEventListener('abort',abort,{once:true})
    operation.then(value=>{signal.removeEventListener('abort',abort);resolve(value)},error=>{signal.removeEventListener('abort',abort);reject(error)})
  })
}
async function probe(file:File,signal:AbortSignal){
  const element=document.createElement('audio'),url=URL.createObjectURL(file)
  let timer:ReturnType<typeof setTimeout>|undefined
  try{
    const duration=await abortable(new Promise<number>((resolve,reject)=>{
      element.onloadedmetadata=()=>resolve(element.duration)
      element.onerror=()=>reject(new ConversionError('codec'))
      timer=setTimeout(()=>reject(new ConversionError('codec')),15000)
      element.preload='metadata';element.src=url
    }),signal)
    if(!Number.isFinite(duration)||duration<=0||duration>conversionLimits.duration)throw new ConversionError('duration')
  }finally{clearTimeout(timer);element.onloadedmetadata=null;element.onerror=null;element.removeAttribute('src');element.load();URL.revokeObjectURL(url)}
}
async function decode(file:File,signal:AbortSignal):Promise<AudioSamples>{
  const context=new AudioContext({sampleRate:48000})
  try{
    const bytes=await abortable(file.arrayBuffer(),signal)
    return await abortable(context.decodeAudioData(bytes),signal)
  }catch(error){if(signal.aborted)throw new DOMException('Cancelled','AbortError');if(error instanceof ConversionError)throw error;throw new ConversionError('codec')}
  finally{await context.close()}
}
export function encodeConversionWav(audio:AudioSamples,signal:AbortSignal):Promise<ArrayBuffer>{
  return new Promise((resolve,reject)=>{
    if(signal.aborted){reject(new DOMException('Cancelled','AbortError'));return}
    const worker=new Worker(new URL('../workers/audioConversion.worker.ts',import.meta.url),{type:'module'})
    const finish=()=>{worker.terminate();signal.removeEventListener('abort',abort)}
    const abort=()=>{finish();reject(new DOMException('Cancelled','AbortError'))}
    signal.addEventListener('abort',abort,{once:true})
    worker.onmessage=event=>{finish();if(event.data.error)reject(new ConversionError('samples'));else resolve(event.data.bytes)}
    worker.onerror=()=>{finish();reject(new ConversionError('codec'))}
    try{const channels=Array.from({length:audio.numberOfChannels},(_,index)=>audio.getChannelData(index).slice());worker.postMessage({sampleRate:audio.sampleRate,channels},channels.map(channel=>channel.buffer))}
    catch(error){finish();reject(error)}
  })
}
export interface ConversionDependencies {probe:(file:File,signal:AbortSignal)=>Promise<void>;decode:(file:File,signal:AbortSignal)=>Promise<AudioSamples>;encode:(audio:AudioSamples,signal:AbortSignal)=>Promise<ArrayBuffer>}
export async function convertToWav(file:File,signal:AbortSignal,onStage:(stage:ConversionStage)=>void,dependencies:ConversionDependencies={probe,decode,encode:encodeConversionWav}){
  onStage('reading')
  const header=await abortable(file.slice(0,16).arrayBuffer(),signal)
  const sourceFormat=validateConversionSource(file.name,file.size,new Uint8Array(header))
  await abortable(dependencies.probe(file,signal),signal)
  onStage('decoding');const audio=await abortable(dependencies.decode(file,signal),signal)
  const duration=validateConversionAudio(audio)
  onStage('encoding');const bytes=await abortable(dependencies.encode(audio,signal),signal)
  onStage('verifying');verifyConversionWav(bytes,audio)
  return {blob:new Blob([bytes],{type:'audio/wav'}),duration,sourceFormat,sampleRate:audio.sampleRate,channels:audio.numberOfChannels}
}
