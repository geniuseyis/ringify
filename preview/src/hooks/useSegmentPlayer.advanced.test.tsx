import {act,cleanup,renderHook} from '@testing-library/react'
import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {FakeAudioContext,audioFixture} from '../test/audioFixtures'
import {useSegmentPlayer} from './useSegmentPlayer'
import {renderSelection} from '../lib/audioProcessing'
import {neutralStudio} from '../lib/studioEffects'
import type {EditorState} from '../types'
const context=vi.hoisted(()=>({value:null as unknown}))
vi.mock('../lib/audio',()=>({getAudioContext:()=>context.value}))
beforeEach(()=>{context.value=new FakeAudioContext()})
afterEach(cleanup)
it('rebuilds real playback when only advanced parameters change and matches export PCM',async()=>{
 const editor:EditorState={asset:{buffer:audioFixture([Array.from({length:4800},(_,i)=>Math.sin(i/2)*.1)],48000),duration:.1,fileName:'real.wav',isDemo:false,peaks:[]},projectName:'test',trimStart:0,trimEnd:.1,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}
 const {result,rerender}=renderHook(({editor})=>useSegmentPlayer(editor),{initialProps:{editor}})
 await act(async()=>result.current.play())
 const ctx=context.value as FakeAudioContext,original=ctx.sources[0].buffer!.getChannelData(0).slice()
 const next={...editor,effects:{...editor.effects,studio:{...neutralStudio,lowPass:1000}}}
 rerender({editor:next});expect(ctx.sources[0].stopped).toBe(true)
 await act(async()=>result.current.play())
 expect(ctx.sources).toHaveLength(2)
 expect(ctx.sources[1].buffer!.getChannelData(0)).toEqual(renderSelection(editor.asset.buffer!,0,.1,next.effects).channels[0])
 expect(ctx.sources[1].buffer!.getChannelData(0)).not.toEqual(original)
})

function validEditor():EditorState {
 return {projectID:'source',projectName:'Source',asset:{buffer:audioFixture([Array(1000).fill(.2)]),duration:10,fileName:'source.wav',isDemo:false,peaks:[]},
  trimStart:0,trimEnd:3,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}
}
it.each(['source','effects'] as const)('ignores a late resume rejection after %s changes',async change=>{
 const editor=validEditor(),ctx=context.value as FakeAudioContext
 let rejectOld!:(error:Error)=>void
 ctx.resume=()=>new Promise<void>((_,reject)=>{rejectOld=reject})
 const {result,rerender}=renderHook(({editor})=>useSegmentPlayer(editor),{initialProps:{editor}})
 let old!:Promise<void>
 act(()=>{old=result.current.play()})
 const next=change==='source'?{...editor,projectID:'replacement',asset:{...editor.asset,buffer:audioFixture([Array(1000).fill(.4)])}}
  :{...editor,effects:{...editor.effects,volume:.5}}
 rerender({editor:next})
 ctx.resume=async()=>undefined
 await act(async()=>{await result.current.play()})
 expect(result.current.isPlaying).toBe(true)
 await act(async()=>{rejectOld(new Error('Old audio permission failure'));await old})
 expect(result.current.error).toBeNull()
 expect(result.current.isPlaying).toBe(true)
 expect(ctx.sources).toHaveLength(1)
})
it('ignores a late resume rejection after the user stops playback',async()=>{
 const ctx=context.value as FakeAudioContext
 let rejectOld!:(error:Error)=>void
 ctx.resume=()=>new Promise<void>((_,reject)=>{rejectOld=reject})
 const editor=validEditor(),{result}=renderHook(()=>useSegmentPlayer(editor))
 let pending!:Promise<void>
 act(()=>{pending=result.current.play()})
 act(()=>result.current.stop())
 await act(async()=>{rejectOld(new Error('Cancelled permission'));await pending})
 expect(result.current.error).toBeNull()
 expect(result.current.isPlaying).toBe(false)
 expect(ctx.sources).toHaveLength(0)
})
