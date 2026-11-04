import {analyzeAudio} from '../lib/audioAnalysis'
self.onmessage=(event:MessageEvent<{channels:Float32Array[];sampleRate:number}>)=>{
  try{self.postMessage({result:analyzeAudio(event.data.channels,event.data.sampleRate)})}
  catch{self.postMessage({error:'Invalid analysis input'})}
}
