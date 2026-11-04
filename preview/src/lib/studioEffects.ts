import type {StudioEffects} from '../types'

export const neutralStudio:StudioEffects={low:0,mid:0,high:0,highPass:0,lowPass:0,channels:'original',limiter:false,ceiling:.99}
export function studioSettings(value?:Partial<StudioEffects>):StudioEffects{
  const result={...neutralStudio,...value}
  if(![result.low,result.mid,result.high,result.highPass,result.lowPass,result.ceiling].every(Number.isFinite)
    ||[result.low,result.mid,result.high].some(value=>Math.abs(value)>12)
    ||[result.highPass,result.lowPass].some(value=>value!==0&&(value<20||value>20000))
    ||result.ceiling<.1||result.ceiling>.99||typeof result.limiter!=='boolean'
    ||!['original','mono','stereo'].includes(result.channels)
    ||result.highPass>0&&result.lowPass>0&&result.highPass>=result.lowPass)throw Error('Invalid studio effects')
  return result
}
export function isNeutralStudio(value?:Partial<StudioEffects>){return JSON.stringify(studioSettings(value))===JSON.stringify(neutralStudio)}
export function validateStudioRate(settings:StudioEffects,rate:number){
  if(([settings.highPass,settings.lowPass].some(value=>value>0&&value>=rate/2))
    ||([settings.low,settings.mid,settings.high].some((gain,index)=>gain!==0&&[120,1000,6000][index]>=rate/2)))throw Error('Effect frequency exceeds source Nyquist limit')
}
export const studioPresets={
  neutral:neutralStudio,
  warm:{...neutralStudio,low:3,high:-2},
  clear:{...neutralStudio,low:-2,mid:2,high:2,highPass:80},
  telephone:{...neutralStudio,highPass:300,lowPass:3400,channels:'mono' as const},
} as const

// RBJ/W3C Audio EQ Cookbook: normalized biquad coefficients; state resets per
// selected render and per channel. No source buffers are changed.
function biquad(values:Float32Array,rate:number,frequency:number,type:'lowpass'|'highpass'|'peak',gain=0){
  const omega=2*Math.PI*frequency/rate,c=Math.cos(omega),alpha=Math.sin(omega)/(2*Math.SQRT1_2),a=10**(gain/40)
  const a0=type==='peak'?1+alpha/a:1+alpha,a1=-2*c/a0,a2=(type==='peak'?1-alpha/a:1-alpha)/a0
  const b0=(type==='peak'?1+alpha*a:type==='lowpass'?(1-c)/2:(1+c)/2)/a0
  const b1=(type==='peak'?-2*c:type==='lowpass'?1-c:-(1+c))/a0
  const b2=(type==='peak'?1-alpha*a:type==='lowpass'?(1-c)/2:(1+c)/2)/a0
  let x1=0,x2=0,y1=0,y2=0
  for(let i=0;i<values.length;i++){
    const x=values[i],y=b0*x+b1*x1+b2*x2-a1*y1-a2*y2
    if(!Number.isFinite(y))throw Error('Invalid filtered audio')
    values[i]=y;x2=x1;x1=x;y2=y1;y1=y
  }
}
export function filterStudio(channels:Float32Array[],rate:number,settings:StudioEffects){
  let output=channels
  if(settings.channels==='mono'&&channels.length===2){
    const mono=new Float32Array(channels[0].length)
    for(let i=0;i<mono.length;i++)mono[i]=(channels[0][i]+channels[1][i])/2
    output=[mono]
  }else if(settings.channels==='stereo'&&channels.length===1)output=[channels[0],channels[0].slice()]
  for(const channel of output){
    if(settings.highPass)biquad(channel,rate,settings.highPass,'highpass')
    if(settings.low)biquad(channel,rate,120,'peak',settings.low)
    if(settings.mid)biquad(channel,rate,1000,'peak',settings.mid)
    if(settings.high)biquad(channel,rate,6000,'peak',settings.high)
    if(settings.lowPass)biquad(channel,rate,settings.lowPass,'lowpass')
  }
  return output
}
// Linked-channel 5ms lookahead, immediate attenuation and 50ms release. Since
// rendering is offline, future peaks are visible without shifting output time.
export function limitPeaks(channels:Float32Array[],rate:number,ceiling:number){
  const length=channels[0]?.length??0
  if(![1,2].includes(channels.length)||length<1||channels.some(channel=>channel.length!==length)
    ||!Number.isFinite(rate)||rate<=0||rate>192000||!Number.isFinite(ceiling)||ceiling<.1||ceiling>.99)throw Error('Invalid limiter format')
  const lookahead=Math.max(1,Math.round(rate*.005)),release=Math.exp(-1/(rate*.05))
  // Only retain the lookahead window: at most 961 entries at 192 kHz.
  // Samples at right have not been modified yet, so no full-length peak copy
  // is required. Match the native limiter's bounded monotonic queue.
  const capacity=Math.min(length,lookahead+1),peaks=new Float64Array(capacity),deque=new Int32Array(capacity)
  let head=0,count=0,right=0,gain=1
  for(let i=0;i<length;i++){
    while(count>0&&deque[head]<i){head=(head+1)%capacity;count--}
    while(right<Math.min(length,i+lookahead+1)){
      let peak=0
      for(const channel of channels){if(!Number.isFinite(channel[right]))throw Error('Invalid audio samples');peak=Math.max(peak,Math.abs(channel[right]))}
      while(count>0&&peaks[(head+count-1)%capacity]<=peak)count--
      const tail=(head+count)%capacity;deque[tail]=right++;peaks[tail]=peak;count++
    }
    const target=peaks[head]>ceiling?ceiling/peaks[head]:1
    gain=Math.min(target,1-(1-gain)*release)
    for(const channel of channels)channel[i]*=gain
  }
}
