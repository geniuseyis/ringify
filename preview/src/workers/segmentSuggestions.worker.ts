import {suggestSegments} from '../lib/segmentSuggestions'
self.onmessage=(event:MessageEvent<{channels:Float32Array[];sampleRate:number;seconds:15|20|29}>)=>{
  try{self.postMessage({segments:suggestSegments(event.data.channels,event.data.sampleRate,event.data.seconds)})}
  catch{self.postMessage({error:true})}
}
