import {encodePCMAsWav} from '../lib/audioProcessing'
import {validateConversionAudio} from '../lib/conversionRules'

// This worker receives copies. Original media and editor buffers are never mutated.
self.onmessage=async(event:MessageEvent<{sampleRate:number;channels:Float32Array[]}>)=>{
  try{
    const {sampleRate,channels}=event.data,length=channels[0]?.length??0
    const duration=validateConversionAudio({sampleRate,length,numberOfChannels:channels.length,getChannelData:index=>channels[index]})
    let peak=0
    for(const channel of channels){
      if(channel.length!==length)throw Error('Channel length mismatch')
      for(const sample of channel){if(!Number.isFinite(sample))throw Error('Invalid sample');peak=Math.max(peak,Math.abs(sample))}
    }
    // Same safe peak ceiling as the existing neutral preview/export pipeline.
    const gain=peak>0?Math.min(1,.99/peak):1
    if(gain!==1)for(const channel of channels)for(let index=0;index<length;index++)channel[index]*=gain
    const bytes=await encodePCMAsWav({sampleRate,channels,length,duration,appliedGain:gain}).arrayBuffer()
    self.postMessage({bytes},{transfer:[bytes]})
  }catch{self.postMessage({error:'Invalid audio'})}
}
