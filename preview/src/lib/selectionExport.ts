import type {AudioEffects} from '../types'
import type {AudioSamples} from './audioProcessing'
import {selectionExportPlan,type WavBitDepth,type WavWorkStage} from './wavExportPlan'

export function renderSelectionExport(buffer:AudioSamples,start:number,end:number,effects:AudioEffects,bitDepth:WavBitDepth,signal:AbortSignal,onStage:(stage:WavWorkStage)=>void):Promise<Blob>{
  return new Promise((resolve,reject)=>{
    if(signal.aborted){reject(new DOMException('Cancelled','AbortError'));return}
    let worker:Worker|null=null,finished=false
    const cleanup=()=>{finished=true;worker?.terminate();signal.removeEventListener('abort',abort)}
    const abort=()=>{cleanup();reject(new DOMException('Cancelled','AbortError'))}
    signal.addEventListener('abort',abort,{once:true})
    try{
      const plan=selectionExportPlan(buffer,start,end,effects,bitDepth)
      const channels=Array.from({length:buffer.numberOfChannels},(_,i)=>buffer.getChannelData(i).slice(plan.first,plan.last))
      if(channels.some(channel=>channel.length!==plan.length))throw Error('Invalid source channel length')
      worker=new Worker(new URL('../workers/selectionExport.worker.ts',import.meta.url),{type:'module'})
      worker.onmessage=event=>{
        if(finished||signal.aborted)return
        if(event.data.kind==='stage'){if(['processing','encoding'].includes(event.data.stage))onStage(event.data.stage);return}
        cleanup()
        if(event.data.kind==='result'&&event.data.bytes instanceof ArrayBuffer)resolve(new Blob([event.data.bytes],{type:'audio/wav'}))
        else reject(new Error(event.data.message||'WAV processing failed'))
      }
      worker.onerror=()=>{if(finished)return;cleanup();reject(Error('WAV worker failed'))}
      worker.onmessageerror=()=>{if(finished)return;cleanup();reject(Error('WAV worker message failed'))}
      worker.postMessage({channels,sampleRate:buffer.sampleRate,effects,bitDepth},channels.map(channel=>channel.buffer))
    }catch(error){cleanup();reject(error)}
  })
}
