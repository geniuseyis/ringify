import {afterEach,describe,expect,it,vi} from 'vitest'
import {limitPeaks} from './studioEffects'

// Independent full-window reference, deliberately simple rather than a queue.
function reference(channels:Float32Array[],rate:number,ceiling:number){
  const output=channels.map(channel=>channel.slice()),length=channels[0].length
  const lookahead=Math.max(1,Math.round(rate*.005)),release=Math.exp(-1/(rate*.05))
  let gain=1
  for(let frame=0;frame<length;frame++){
    let peak=0
    for(let next=frame;next<Math.min(length,frame+lookahead+1);next++)for(const channel of channels)peak=Math.max(peak,Math.abs(channel[next]))
    const target=peak>ceiling?ceiling/peak:1
    gain=Math.min(target,1-(1-gain)*release)
    for(let channel=0;channel<channels.length;channel++)output[channel][frame]*=gain
  }
  return output
}

afterEach(()=>vi.unstubAllGlobals())
describe('Bounded linked peak limiter',()=>{
  it.each([1,1000,48000,192000])('matches an independent window reference at %s Hz, including queue wrap and EOF',rate=>{
    const left=Float32Array.from({length:2049},(_,i)=>Math.sin(i*.731)*(i%53===0?2.5:.2))
    const right=Float32Array.from(left,(value,i)=>i===2048?-3:-value*.37)
    const expected=reference([left,right],rate,.7),actual=[left.slice(),right.slice()]
    limitPeaks(actual,rate,.7)
    expect(actual).toEqual(expected)
    expect(actual.every(channel=>channel.every(sample=>Math.abs(sample)<=.700001))).toBe(true)
  })
  it('handles a source shorter than lookahead and silence without shifting samples',()=>{
    for(const source of [new Float32Array([0,0,0]),new Float32Array([2,.1,-3])]){
      const actual=[source.slice()];limitPeaks(actual,192000,.8)
      expect(actual).toEqual(reference([source],192000,.8));expect(actual[0]).toHaveLength(3)
    }
  })
  it('bounds both scratch allocations to 961 entries regardless of source length',()=>{
    const source=[new Float32Array(12000).fill(.2)],allocations:number[]=[]
    const Float64=Float64Array,Int32=Int32Array
    vi.stubGlobal('Float64Array',class extends Float64{constructor(length:number){allocations.push(length);super(length)}})
    vi.stubGlobal('Int32Array',class extends Int32{constructor(length:number){allocations.push(length);super(length)}})
    limitPeaks(source,192000,.8)
    expect(allocations).toEqual([961,961])
  })
  it.each([0,NaN,Infinity,192001])('rejects invalid rate %s',rate=>expect(()=>limitPeaks([new Float32Array([.1])],rate,.8)).toThrow(/format/))
  it('rejects malformed channel layouts and nonfinite samples',()=>{
    for(const channels of [[],[new Float32Array()],[new Float32Array(2),new Float32Array(1)]])expect(()=>limitPeaks(channels,48000,.8)).toThrow(/format/)
    expect(()=>limitPeaks([new Float32Array([.1,NaN])],48000,.8)).toThrow(/samples/)
  })
})
