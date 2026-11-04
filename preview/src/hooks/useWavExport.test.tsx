import {act,cleanup,renderHook} from '@testing-library/react'
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import * as audio from '../lib/audio'
import {audioFixture} from '../test/audioFixtures'
import type {EditorState} from '../types'
import {useWavExport} from './useWavExport'
vi.mock('../lib/selectionExport',async()=>({renderSelectionExport:(await import('../test/selectionExportFixture')).selectionExportFixture}))

const createUrl=vi.fn(()=> 'blob:verified-wav'),revokeUrl=vi.fn()
const originalCreate=Object.getOwnPropertyDescriptor(URL,'createObjectURL'),originalRevoke=Object.getOwnPropertyDescriptor(URL,'revokeObjectURL')
beforeEach(()=>{vi.useFakeTimers();vi.clearAllMocks();Object.defineProperty(URL,'createObjectURL',{configurable:true,value:createUrl});Object.defineProperty(URL,'revokeObjectURL',{configurable:true,value:revokeUrl})})
afterEach(()=>{cleanup();vi.useRealTimers();vi.restoreAllMocks();if(originalCreate)Object.defineProperty(URL,'createObjectURL',originalCreate);else Reflect.deleteProperty(URL,'createObjectURL');if(originalRevoke)Object.defineProperty(URL,'revokeObjectURL',originalRevoke);else Reflect.deleteProperty(URL,'revokeObjectURL')})
function fixture():EditorState{return {projectID:'export-source',projectName:'My Tone',asset:{fileName:'source.wav',duration:4,peaks:[.25,.25],buffer:audioFixture([Array<number>(400).fill(.25)],100),isDemo:false},trimStart:.5,trimEnd:2.5,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}}
function deferred(){let resolve!:()=>void;const promise=new Promise<void>(done=>{resolve=done});return {promise,resolve}}

describe('Verified WAV export job',()=>{
 it('verifies actual PCM24 metadata and invalidates the old download when the profile changes',async()=>{
  const editor=fixture(),persist=vi.fn().mockResolvedValue(undefined)
  const {result,rerender}=renderHook(({bits}:{bits:16|24})=>useWavExport(editor,persist,'tr',bits),{initialProps:{bits:24 as 16|24}})
  await act(async()=>{const pending=result.current.start('Precision');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.result).toMatchObject({bitDepth:24,channels:1,sampleRate:100,duration:2})
  expect(result.current.result!.blob.size).toBe(644)
  rerender({bits:16});expect(result.current.result).toBeNull();expect(revokeUrl).toHaveBeenCalledWith('blob:verified-wav')
 })
 it('fails before committing a header whose rate disagrees with the intended source',async()=>{
  const editor=fixture(),encoded=audio.encodeSelectionAsWav(editor.asset.buffer!,.5,2.5,editor.effects),bytes=await encoded.arrayBuffer()
  new DataView(bytes).setUint32(24,200,true)
  vi.spyOn(audio,'encodeSelectionAsWav').mockReturnValueOnce(new Blob([bytes],{type:'audio/wav'}))
  const persist=vi.fn(),{result}=renderHook(()=>useWavExport(editor,persist,'en'))
  await act(async()=>{const pending=result.current.start('Wrong rate');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.status).toBe('error');expect(persist).not.toHaveBeenCalled();expect(createUrl).not.toHaveBeenCalled()
 })
 it('encodes real bytes once, waits for persistence, then exposes the real result',async()=>{
  const saved=deferred(),persist=vi.fn<(name:string,blob:Blob)=>Promise<void>>(()=>saved.promise),editor=fixture();const {result}=renderHook(()=>useWavExport(editor,persist,'tr'))
  expect(persist).not.toHaveBeenCalled();expect(createUrl).not.toHaveBeenCalled()
  let first!:Promise<void>,duplicate!:Promise<void>
  act(()=>{first=result.current.start('Tone?');duplicate=result.current.start('Duplicate')})
  expect(result.current.status).toBe('preparing')
  await act(async()=>{await vi.runOnlyPendingTimersAsync();await duplicate})
  expect(result.current.status).toBe('saving');expect(persist).toHaveBeenCalledTimes(1);expect(persist.mock.calls[0][0]).toBe('Tone-');expect(result.current.result).toBeNull();expect(createUrl).not.toHaveBeenCalled()
  await act(async()=>{saved.resolve();await first})
  const wav=result.current.result!;const bytes=new DataView(await wav.blob.arrayBuffer())
  expect(result.current.status).toBe('success');expect(wav.fileName).toBe('Tone-.wav');expect(wav.duration).toBe(2);expect(wav.blob.size).toBe(444);expect(bytes.getUint32(40,true)).toBe(400);expect(bytes.getUint16(34,true)).toBe(16);expect(createUrl).toHaveBeenCalledExactlyOnceWith(wav.blob)
 })
 it('cancels before encoding/commit and never publishes a stale file',async()=>{
  const persist=vi.fn().mockResolvedValue(undefined),editor=fixture();const {result}=renderHook(()=>useWavExport(editor,persist,'tr'));let pending!:Promise<void>
  act(()=>{pending=result.current.start('Cancelled');result.current.cancel()})
  await act(async()=>{await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.status).toBe('idle');expect(result.current.result).toBeNull();expect(persist).not.toHaveBeenCalled();expect(createUrl).not.toHaveBeenCalled()
 })
 it('does not pretend a persistence commit can be cancelled',async()=>{
  const saved=deferred(),persist=vi.fn(()=>saved.promise),editor=fixture();const {result}=renderHook(()=>useWavExport(editor,persist,'tr'));let pending!:Promise<void>
  act(()=>{pending=result.current.start('Committed')});await act(async()=>{await vi.runOnlyPendingTimersAsync()})
  act(()=>result.current.cancel());expect(result.current.status).toBe('saving')
  await act(async()=>{saved.resolve();await pending});expect(result.current.status).toBe('success');expect(persist).toHaveBeenCalledOnce()
 })
 it('suppresses delayed completion and URLs after unmount',async()=>{
  const saved=deferred(),persist=vi.fn(()=>saved.promise),editor=fixture();const {result,unmount}=renderHook(()=>useWavExport(editor,persist,'tr'));let pending!:Promise<void>
  act(()=>{pending=result.current.start('Old')});await act(async()=>{await vi.runOnlyPendingTimersAsync()});unmount()
  await act(async()=>{saved.resolve();await pending});expect(createUrl).not.toHaveBeenCalled();expect(persist).toHaveBeenCalledOnce()
 })
 it('surfaces save failures, retries real encoding and revokes the successful URL',async()=>{
  const persist=vi.fn().mockRejectedValueOnce(new Error('Quota exceeded')).mockResolvedValue(undefined),editor=fixture();const {result,unmount}=renderHook(()=>useWavExport(editor,persist,'en'))
  await act(async()=>{const pending=result.current.start('Retry');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.status).toBe('error');expect(result.current.error).toBe('Quota exceeded');expect(createUrl).not.toHaveBeenCalled()
  await act(async()=>{const pending=result.current.start('Retry');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.status).toBe('success');expect(result.current.error).toBeNull();expect(persist).toHaveBeenCalledTimes(2);unmount();expect(revokeUrl).toHaveBeenCalledExactlyOnceWith('blob:verified-wav')
 })
 it('invalidates a previous project result and releases its URL when the source identity changes',async()=>{
  const persist=vi.fn().mockResolvedValue(undefined),editor=fixture();const {result,rerender}=renderHook(({editor})=>useWavExport(editor,persist,'tr'),{initialProps:{editor}})
  await act(async()=>{const pending=result.current.start('First');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.result).not.toBeNull();rerender({editor:{...editor,projectID:'other-project'}})
  expect(result.current.result).toBeNull();expect(result.current.status).toBe('idle');expect(revokeUrl).toHaveBeenCalledExactlyOnceWith('blob:verified-wav')
 })
 it('rejects malformed output before the persistence callback',async()=>{
  vi.spyOn(audio,'encodeSelectionAsWav').mockReturnValueOnce(new Blob(['not a valid waveform'],{type:'audio/wav'}))
  const persist=vi.fn().mockResolvedValue(undefined),editor=fixture();const {result}=renderHook(()=>useWavExport(editor,persist,'en'))
  await act(async()=>{const pending=result.current.start('Broken');await vi.runOnlyPendingTimersAsync();await pending})
  expect(result.current.status).toBe('error');expect(result.current.error).toMatch(/verified/);expect(persist).not.toHaveBeenCalled();expect(createUrl).not.toHaveBeenCalled()
 })
 it.each(['empty name','missing source'])('blocks %s without a fake result',async(kind)=>{
  const editor=fixture();if(kind==='missing source')editor.asset.buffer=null;const persist=vi.fn().mockResolvedValue(undefined);const {result}=renderHook(()=>useWavExport(editor,persist,'tr'))
  await act(async()=>{await result.current.start(kind==='empty name'?'...':'Name')})
  expect(result.current.status).toBe('error');expect(result.current.result).toBeNull();expect(persist).not.toHaveBeenCalled();expect(createUrl).not.toHaveBeenCalled()
 })
})
