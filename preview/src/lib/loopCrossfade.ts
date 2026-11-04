export function validateLoopCrossfade(seconds:number){
  if(!Number.isFinite(seconds)||seconds!==0&&(seconds<.005||seconds>.25))throw Error('Invalid loop overlap')
}
export function loopOverlapFrames(seconds:number,rate:number,frames:number){
  validateLoopCrossfade(seconds)
  if(!Number.isFinite(rate)||rate<=0||rate>192000
    ||!Number.isSafeInteger(frames)||frames<1)throw Error('Invalid loop overlap')
  if(seconds===0)return 0
  const overlap=Math.min(Math.round(seconds*rate),Math.floor(frames/4))
  if(overlap<2)throw Error('Audio selection is too short for overlap')
  return overlap
}

// Takes owned rendered buffers, never the user's AudioBuffer. Move the middle
// in place and blend the tail into the retained head. Extra memory is <=48000
// samples/channel; output length is input-overlap, with original adjacent joins.
export function crossfadeOwnedLoop(channels:Float32Array[],rate:number,seconds:number){
  const frames=channels[0]?.length??0,overlap=loopOverlapFrames(seconds,rate,frames)
  if(![1,2].includes(channels.length)||channels.some(c=>c.length!==frames||c.some(v=>!Number.isFinite(v))))throw Error('Invalid loop samples')
  if(!overlap)return {channels,length:frames,sourceOffset:0}
  const output=channels.map(channel=>{
    const head=channel.slice(0,overlap)
    channel.copyWithin(0,overlap,frames-overlap)
    for(let i=0;i<overlap;i++){
      const blend=i/(overlap-1),value=channel[frames-overlap+i]*(1-blend)+head[i]*blend
      if(!Number.isFinite(value))throw Error('Invalid crossfade sample')
      channel[frames-2*overlap+i]=value
    }
    return channel.subarray(0,frames-overlap)
  })
  return {channels:output,length:frames-overlap,sourceOffset:overlap/rate}
}
