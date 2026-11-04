import {describe,it,expect} from 'vitest'
import {suggestSegments,validSegmentSuggestions} from './segmentSuggestions'

describe('deterministic source segment ranking',()=>{
  it('accepts actual ranked worker results for every target and a noninteger 50ms grid',()=>{
    for(const rate of [100,11025])for(const seconds of [15,20,29] as const){
      const source=new Float32Array(Math.round(31.037*rate)).fill(.5)
      const result=suggestSegments([source],rate,seconds)
      expect(validSegmentSuggestions(result,source.length/rate,rate,seconds)).toBe(true)
    }
  })
  it('accepts exact short-source and empty results without permitting a mismatched target',()=>{
    expect(validSegmentSuggestions([{start:0,end:1.03,rmsDbFS:-6}],1.03,100,29)).toBe(true)
    expect(validSegmentSuggestions([],0.99,100,29)).toBe(true)
    expect(validSegmentSuggestions([{start:0,end:15,rmsDbFS:-6}],60,100,29)).toBe(false)
  })
  it('rejects invalid result metadata and oversized batches',()=>{
    expect(validSegmentSuggestions([],NaN,100,29)).toBe(false)
    expect(validSegmentSuggestions([],121,100,29)).toBe(false)
    expect(validSegmentSuggestions([],60,0,29)).toBe(false)
    expect(validSegmentSuggestions(null,60,100,29)).toBe(false)
    expect(validSegmentSuggestions([{start:'0',end:29,rmsDbFS:-6}],60,100,29)).toBe(false)
    expect(validSegmentSuggestions(Array.from({length:4},(_,i)=>({start:i*15,end:(i+1)*15,rmsDbFS:-6})),60,100,15)).toBe(false)
  })
  it('ranks energy, never overlaps candidates, and leaves original PCM untouched',()=>{
    const source=new Float32Array(6000);source.fill(.2,0,1500);source.fill(.9,2000,3500);source.fill(.5,4000,5500)
    const before=source.slice(),result=suggestSegments([source],100,15)
    expect(result.map(item=>[item.start,item.end])).toEqual([[20,35],[40,55],[0,15]])
    expect(result[0].rmsDbFS).toBeCloseTo(20*Math.log10(.9),4)
    expect(source).toEqual(before)
  })
  it('keeps stereo energy even when the channels are in opposite phase',()=>{
    const a=new Float32Array(3000).fill(.5),b=new Float32Array(3000).fill(-.5)
    expect(suggestSegments([a,b],100,15).map(item=>item.start)).toEqual([0,15])
    expect(suggestSegments([a,b],100,15)[0].rmsDbFS).toBeCloseTo(-6.0206,3)
  })
  it('evaluates the exact source end beyond the 50ms grid',()=>{
    const source=new Float32Array(2003);source.fill(.8,503)
    expect(suggestSegments([source],100,15)[0]).toMatchObject({start:5.03,end:20.03})
  })
  it('returns the available duration for a short source, and nothing for silence/subsecond input',()=>{
    expect(suggestSegments([new Float32Array(103).fill(.2)],100,29)[0]).toMatchObject({start:0,end:1.03})
    expect(suggestSegments([new Float32Array(6000)],100,15)).toEqual([])
    expect(suggestSegments([new Float32Array(99)],100,15)).toEqual([])
  })
  it('rejects nonfinite samples, mismatched channels and unbounded input',()=>{
    expect(()=>suggestSegments([new Float32Array(200).fill(NaN)],100,15)).toThrow('Invalid source samples')
    expect(()=>suggestSegments([new Float32Array(100),new Float32Array(101)],100,15)).toThrow()
    expect(()=>suggestSegments([new Float32Array(12100)],100,15)).toThrow()
    expect(()=>suggestSegments([new Float32Array(100)],0,15)).toThrow()
    expect(()=>suggestSegments(Array.from({length:3},()=>new Float32Array(100)),100,15)).toThrow()
  })
})
