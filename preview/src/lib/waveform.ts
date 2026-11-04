import type {AudioSamples} from './audioProcessing'
export function calculatePeaks(buffer:AudioSamples,count:number){
  if(count<=0)return []
  if(!Number.isInteger(count)||count>10000)throw Error('Invalid waveform resolution')
  const peaks=new Array<number>(count).fill(0)
  for(let channel=0;channel<buffer.numberOfChannels;channel++){
    const values=buffer.getChannelData(channel)
    if(values.length!==buffer.length)throw Error('Invalid waveform source')
    for(let frame=0;frame<buffer.length;frame++){
      if(!Number.isFinite(values[frame]))throw Error('Invalid audio samples')
      const bucket=Math.min(count-1,Math.floor(frame/buffer.length*count))
      peaks[bucket]=Math.max(peaks[bucket],Math.min(1,Math.abs(values[frame])))
    }
  }
  return peaks
}
export function calculatePeaksAsync(buffer:AudioSamples,count:number,signal?:AbortSignal):Promise<number[]>{
  return new Promise((resolve,reject)=>{
    let worker:Worker|undefined,timer:ReturnType<typeof setTimeout>|undefined
    const abort=()=>{finish();reject(new DOMException('Cancelled','AbortError'))}
    const finish=()=>{clearTimeout(timer);worker?.terminate();signal?.removeEventListener('abort',abort)}
    try{
      if(signal?.aborted){abort();return}
      const channels=Array.from({length:buffer.numberOfChannels},(_,i)=>buffer.getChannelData(i).slice())
      worker=new Worker(new URL('../workers/waveform.worker.ts',import.meta.url),{type:'module'})
      signal?.addEventListener('abort',abort,{once:true})
      timer=setTimeout(()=>{finish();reject(Error('Waveform timed out'))},20000)
      worker.onerror=()=>{finish();reject(Error('Waveform failed'))}
      worker.onmessage=event=>{finish();const peaks=event.data.peaks;if(!Array.isArray(peaks)||peaks.length!==count||peaks.some(p=>!Number.isFinite(p)||p<0||p>1))reject(Error('Invalid waveform'));else resolve(peaks)}
      worker.postMessage({channels,count},channels.map(channel=>channel.buffer))
    }catch(error){finish();reject(error)}
  })
}
