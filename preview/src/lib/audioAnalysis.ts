export interface AudioAnalysis {peakDbFS:number|null;rmsDbFS:number|null;silentRegions:{start:number;end:number}[];suggestion:{start:number;end:number}|null;duration:number}
// Source PCM statistics and deterministic silence, not LUFS, speech detection or AI.
export function analyzeAudio(channels:Float32Array[],sampleRate:number):AudioAnalysis{
  const length=channels[0]?.length??0,duration=length/sampleRate
  if(!Number.isFinite(sampleRate)||sampleRate<=0||!length||channels.length>2||channels.some(channel=>channel.length!==length)||duration>29.001)throw Error('Invalid analysis input')
  const window=Math.max(1,Math.round(sampleRate*.05)),threshold=10**(-45/20),minimum=.3
  let peak=0,sum=0,silenceStart:number|null=null
  const silentRegions:{start:number;end:number}[]=[]
  for(let first=0;first<length;first+=window){
    const last=Math.min(length,first+window);let square=0
    for(const channel of channels)for(let i=first;i<last;i++){const value=channel[i];if(!Number.isFinite(value))throw Error('Invalid samples');peak=Math.max(peak,Math.abs(value));square+=value*value}
    sum+=square
    const silent=Math.sqrt(square/((last-first)*channels.length))<=threshold
    if(silent&&silenceStart===null)silenceStart=first/sampleRate
    if(!silent&&silenceStart!==null){if(first/sampleRate-silenceStart>=minimum-1e-8)silentRegions.push({start:silenceStart,end:first/sampleRate});silenceStart=null}
  }
  if(silenceStart!==null&&duration-silenceStart>=minimum-1e-8)silentRegions.push({start:silenceStart,end:duration})
  const db=(value:number)=>value>0?20*Math.log10(value):null
  const start=silentRegions[0]?.start===0?silentRegions[0].end:0
  const last=silentRegions.at(-1),end=last?.end===duration?last.start:duration
  return {peakDbFS:db(peak),rmsDbFS:db(Math.sqrt(sum/(length*channels.length))),silentRegions,duration,
    suggestion:end-start>=1&&end-start<duration?{start,end}:null}
}
