export interface SegmentSuggestion {start:number;end:number;rmsDbFS:number}

// A worker boundary is untrusted. Validate the complete result as a batch so
// corrupt replies cannot expose wrong-length, overlapping or misranked trims.
export function validSegmentSuggestions(value:unknown,duration:number,rate:number,seconds:15|20|29):value is SegmentSuggestion[]{
  if(!Number.isFinite(duration)||duration<=0||duration>120||!Number.isFinite(rate)||rate<=0
    ||![15,20,29].includes(seconds)||!Array.isArray(value)||value.length>3)return false
  const expected=Math.min(duration,Math.round(seconds*rate)/rate),tolerance=Math.max(1/rate,1e-8)
  const seen:SegmentSuggestion[]=[]
  for(const item of value){
    if(!item||typeof item!=='object')return false
    const {start,end,rmsDbFS}=item
    if(typeof start!=='number'||typeof end!=='number'||typeof rmsDbFS!=='number'
      ||![start,end,rmsDbFS].every(Number.isFinite)||start<0||end>duration||end-start<1||end-start>29+1e-8
      ||Math.abs(end-start-expected)>tolerance||rmsDbFS< -45-1e-6
      ||seen.some(other=>end>other.start&&start<other.end)
      ||seen.length>0&&rmsDbFS>seen.at(-1)!.rmsDbFS+1e-8)return false
    seen.push({start,end,rmsDbFS})
  }
  return true
}

// Deterministic energy ranking on a 50ms search grid. Not speech/music/AI inference.
export function suggestSegments(channels:Float32Array[],sampleRate:number,seconds:15|20|29):SegmentSuggestion[]{
  const length=channels[0]?.length??0
  if(!Number.isFinite(sampleRate)||sampleRate<=0||!length||channels.length<1||channels.length>2||![15,20,29].includes(seconds)
    ||channels.some(c=>c.length!==length)||length/sampleRate>120||length*channels.length*4>48*1024*1024)throw Error('Unsupported suggestion source')
  if(length/sampleRate<1)return []
  const step=Math.max(1,Math.round(sampleRate*.05)),bins=Math.ceil(length/step),prefix=new Float64Array(bins+1)
  for(let b=0;b<bins;b++){
    let energy=0
    for(const channel of channels)for(let i=b*step;i<Math.min(length,(b+1)*step);i++){const v=channel[i];if(!Number.isFinite(v))throw Error('Invalid source samples');energy+=v*v}
    prefix[b+1]=prefix[b]+energy
  }
  function partial(first:number,last:number){let sum=0;for(const channel of channels)for(let i=first;i<last;i++)sum+=channel[i]*channel[i];return sum}
  function energy(first:number,last:number){const left=Math.ceil(first/step),right=Math.floor(last/step);return left>right?partial(first,last):partial(first,left*step)+(prefix[right]-prefix[left])+partial(right*step,last)}
  const frames=Math.min(length,Math.round(seconds*sampleRate)),starts=[]
  for(let first=0;first<=length-frames;first+=step)starts.push(first)
  if(starts.at(-1)!==length-frames)starts.push(length-frames)
  const ranked=starts.map(first=>({first,last:first+frames,power:energy(first,first+frames)/(frames*channels.length)}))
    .filter(item=>item.power>=10**(-45/10)).sort((a,b)=>b.power-a.power||a.first-b.first)
  const chosen:typeof ranked=[]
  for(const item of ranked){if(chosen.every(other=>item.last<=other.first||item.first>=other.last)){chosen.push(item);if(chosen.length===3)break}}
  return chosen.map(item=>({start:item.first/sampleRate,end:item.last/sampleRate,rmsDbFS:10*Math.log10(item.power)}))
}
