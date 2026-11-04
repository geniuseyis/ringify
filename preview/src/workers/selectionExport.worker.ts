import {renderSelection,encodePCMAsWav} from '../lib/audioProcessing'
import type {AudioEffects} from '../types'
import type {WavBitDepth} from '../lib/wavExportPlan'
self.onmessage=async(event:MessageEvent<{channels:Float32Array[];sampleRate:number;effects:AudioEffects;bitDepth:WavBitDepth}>)=>{
  try{
    const {channels,sampleRate,effects,bitDepth}=event.data,length=channels[0]?.length??0
    if(!length||channels.some(channel=>channel.length!==length))throw Error('Invalid source samples')
    self.postMessage({kind:'stage',stage:'processing'})
    const pcm=renderSelection({sampleRate,length,numberOfChannels:channels.length,getChannelData:i=>channels[i]},0,length/sampleRate,effects)
    self.postMessage({kind:'stage',stage:'encoding'})
    const bytes=await encodePCMAsWav(pcm,bitDepth).arrayBuffer()
    self.postMessage({kind:'result',bytes},{transfer:[bytes]})
  }catch(error){self.postMessage({kind:'error',message:error instanceof Error?error.message:'WAV processing failed'})}
}
