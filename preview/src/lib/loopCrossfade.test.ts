import {describe,it,expect} from 'vitest'
import {crossfadeOwnedLoop,loopOverlapFrames} from './loopCrossfade'
import {renderSelection,encodePCMAsWav} from './audioProcessing'
import {selectionExportPlan,verifySelectionWav} from './wavExportPlan'
import {SegmentPlayer} from './segmentPlayer'
import {FakeAudioContext,audioFixture} from '../test/audioFixtures'
const effects={volume:1,fadeIn:0,fadeOut:0,normalize:false,loopCrossfade:.03}
describe('real loop overlap',()=>{
  it('matches the same golden vector as the streaming Swift processor',()=>{
    const values=Float32Array.from({length:12},(_,i)=>i/100)
    const output=crossfadeOwnedLoop([values],8000,.005)
    const expected=[.03,.04,.05,.06,.07,.08,.09,.055,.02]
    expect(output.length).toBe(9)
    output.channels[0].forEach((value,i)=>expect(value).toBeCloseTo(expected[i],6))
  })
  it('preserves source buffers and joins the wrap at original adjacent head samples',()=>{
    const source=audioFixture([[...Array<number>(4000).fill(.4),...Array<number>(4000).fill(-.4)]],8000)
    const original=source.getChannelData(0).slice(),pcm=renderSelection(source,0,1,effects)
    expect(pcm.length).toBe(7760);expect(pcm.sourceOffset).toBe(.03)
    expect(pcm.channels[0][0]).toBe(pcm.channels[0].at(-1))
    expect(pcm.channels[0].every(value=>Math.abs(value)<=.400001)).toBe(true)
    expect(source.getChannelData(0)).toEqual(original)
  })
  it('uses the same frame count and samples for playback and verified WAV output',async()=>{
    const source=audioFixture([Array<number>(8000).fill(.4)],8000),pcm=renderSelection(source,0,1,effects)
    const plan=selectionExportPlan(source,0,1,effects),bytes=await encodePCMAsWav(pcm).arrayBuffer()
    expect(plan.outputLength).toBe(pcm.length);expect(plan.duration).toBe(pcm.duration)
    verifySelectionWav(bytes,plan)
    const view=new DataView(bytes)
    expect(view.getUint32(40,true)/2).toBe(pcm.length)
    for(const i of [0,100,pcm.length-1])expect(view.getInt16(44+i*2,true)/32767).toBeCloseTo(pcm.channels[0][i],4)
  })
  it('loops and resumes using rendered duration while reporting source coordinates',async()=>{
    const context=new FakeAudioContext(),source=audioFixture([Array<number>(8000).fill(.2)],8000)
    const player=new SegmentPlayer(context as unknown as AudioContext,source,0,1,effects)
    player.setLoop(true);await player.play()
    expect(context.sources[0].loopEnd).toBe(.97)
    expect(context.sources[0].buffer?.length).toBe(7760)
    context.currentTime=1.5
    expect(player.position).toBeCloseTo(.53,8);expect(player.sourcePosition).toBeCloseTo(.56,8)
    player.pause();context.currentTime=3;await player.play()
    expect(context.sources[1].starts[0]).toBeCloseTo(.53,8)
  })
  it('rejects invalid overlap, sample data and too-short selections',()=>{
    for(const value of [NaN,-1,.001,.3])expect(()=>loopOverlapFrames(value,48000,48000)).toThrow()
    expect(()=>crossfadeOwnedLoop([new Float32Array([NaN,0,0,0,0,0,0,0])],8000,.03)).toThrow()
    expect(()=>loopOverlapFrames(.03,8000,2)).toThrow()
  })
})
