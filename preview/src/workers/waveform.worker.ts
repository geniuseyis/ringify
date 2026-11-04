import {calculatePeaks} from '../lib/waveform'
self.onmessage=event=>{
  try{const {channels,count}=event.data as {channels:Float32Array[];count:number};if(![1,2].includes(channels.length))throw Error();self.postMessage({peaks:calculatePeaks({length:channels[0].length,numberOfChannels:channels.length,sampleRate:1,getChannelData:i=>channels[i]},count)})}
  catch{self.postMessage({error:true})}
}
