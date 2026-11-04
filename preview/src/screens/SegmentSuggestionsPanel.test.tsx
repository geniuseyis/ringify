import {act,cleanup,fireEvent,render,screen} from '@testing-library/react'
import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {SegmentSuggestionsPanel} from './SegmentSuggestionsPanel'
import {emptyAudio} from '../test/audioFixtures'
import type {EditorState} from '../types'
let job:TestWorker
class TestWorker{onmessage:((event:{data:unknown})=>void)|null=null;onerror:(()=>void)|null=null;terminate=vi.fn();postMessage=vi.fn();constructor(){job=this}}
beforeEach(()=>vi.stubGlobal('Worker',TestWorker))
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
function editor():EditorState{return{projectID:'one',projectName:'Source',asset:{fileName:'source.wav',duration:60,peaks:[],isDemo:false,buffer:emptyAudio(1,6000,100)},trimStart:0,trimEnd:29,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}}
it('transfers a bounded source copy and applies source-relative times without altering effects',()=>{
  const source=editor(),change=vi.fn();render(<SegmentSuggestionsPanel editor={source} language="tr" onChange={change}/>)
  fireEvent.click(screen.getByRole('button',{name:'Kaynakta bölüm bul'}))
  expect(job.postMessage.mock.calls[0][0].channels[0]).not.toBe(source.asset.buffer!.getChannelData(0))
  expect(job.postMessage.mock.calls[0][0].seconds).toBe(29)
  act(()=>job.onmessage!({data:{segments:[{start:12,end:41,rmsDbFS:-9}]}}))
  fireEvent.click(screen.getByRole('button',{name:/1\..*dBFS/}))
  expect(change).toHaveBeenCalledWith({...source,trimStart:12,trimEnd:41});expect(source.trimStart).toBe(0)
})
it('cancels and ignores late replies; changing duration clears previous suggestions',()=>{
  render(<SegmentSuggestionsPanel editor={editor()} language="tr" onChange={vi.fn()}/>)
  fireEvent.click(screen.getByRole('button',{name:'Kaynakta bölüm bul'}));const old=job
  fireEvent.click(screen.getByRole('button',{name:'Taramayı iptal et'}));expect(old.terminate).toHaveBeenCalled()
  act(()=>old.onmessage!({data:{segments:[{start:0,end:29,rmsDbFS:-3}]}}))
  expect(screen.queryByRole('button',{name:/dBFS/})).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Kaynakta bölüm bul'}));act(()=>job.onmessage!({data:{segments:[{start:0,end:29,rmsDbFS:-3}]}}))
  fireEvent.change(screen.getByRole('combobox'),{target:{value:'15'}})
  expect(screen.queryByRole('button',{name:/dBFS/})).not.toBeInTheDocument()
})
it('rejects corrupt worker replies and terminates on source change/unmount',()=>{
  const source=editor(),view=render(<SegmentSuggestionsPanel editor={source} language="en" onChange={vi.fn()}/>)
  fireEvent.click(screen.getByRole('button',{name:'Find source segments'}));act(()=>job.onmessage!({data:{segments:[null]}}))
  expect(screen.getByRole('alert')).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button',{name:'Find source segments'}));const old=job
  view.rerender(<SegmentSuggestionsPanel editor={{...source,asset:{...source.asset,buffer:emptyAudio(1,6000,100)}}} language="en" onChange={vi.fn()}/>);expect(old.terminate).toHaveBeenCalled()
  fireEvent.click(screen.getByRole('button',{name:'Find source segments'}));const last=job;view.unmount();expect(last.terminate).toHaveBeenCalled()
})

it.each([
  ['null payload',null],
  ['wrong target length',{segments:[{start:0,end:15,rmsDbFS:-6}]}],
  ['overlapping regions',{segments:[{start:0,end:29,rmsDbFS:-6},{start:10,end:39,rmsDbFS:-9}]}],
  ['inverted energy ranking',{segments:[{start:0,end:29,rmsDbFS:-12},{start:30,end:59,rmsDbFS:-6}]}],
  ['below-threshold region',{segments:[{start:0,end:29,rmsDbFS:-50}]}],
  ['duplicate region',{segments:[{start:0,end:29,rmsDbFS:-6},{start:0,end:29,rmsDbFS:-6}]}],
  ['beyond the actual source',{segments:[{start:31.001,end:60.001,rmsDbFS:-6}]}],
  ['nonfinite level',{segments:[{start:0,end:29,rmsDbFS:NaN}]}],
  ['missing result array',{}],
] as const)('rejects %s without exposing an apply action',(_name,payload)=>{
  const change=vi.fn()
  render(<SegmentSuggestionsPanel editor={editor()} language="en" onChange={change}/>)
  fireEvent.click(screen.getByRole('button',{name:'Find source segments'}))
  expect(()=>act(()=>job.onmessage!({data:payload}))).not.toThrow()
  expect(screen.getByRole('alert')).toBeInTheDocument()
  expect(screen.queryByRole('button',{name:/dBFS/})).not.toBeInTheDocument()
  expect(change).not.toHaveBeenCalled()
  expect(job.terminate).toHaveBeenCalled()
  expect(screen.getByRole('button',{name:'Find source segments'})).toBeEnabled()
})
