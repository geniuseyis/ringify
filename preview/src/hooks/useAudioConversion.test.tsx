import {act,cleanup,renderHook} from '@testing-library/react'
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest'
import {convertToWav} from '../lib/audioConversion'
import {useAudioConversion} from './useAudioConversion'
vi.mock('../lib/audioConversion',()=>({convertToWav:vi.fn()}))
const output={blob:new Blob(['wav']),duration:40,sourceFormat:'mp3' as const,sampleRate:48000,channels:1}
const create=vi.fn(()=> 'blob:conversion'),revoke=vi.fn()
class TestURL extends URL {static createObjectURL=create;static revokeObjectURL=revoke}
beforeEach(()=>{vi.clearAllMocks();vi.stubGlobal('URL',TestURL);vi.mocked(convertToWav).mockResolvedValue(output)})
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
describe('Conversion lifecycle',()=>{
 it('publishes only verified output and revokes it on source reset',async()=>{
  const {result}=renderHook(useAudioConversion)
  await act(async()=>result.current.start(new File(['mp3'],'source.mp3')))
  expect(result.current.stage).toBe('success');expect(result.current.result?.duration).toBe(40)
  act(()=>result.current.reset());expect(revoke).toHaveBeenCalledWith('blob:conversion');expect(result.current.result).toBeNull()
 })
 it('prevents duplicate jobs and suppresses late success after cancellation',async()=>{
  let release!:(value:typeof output)=>void
  vi.mocked(convertToWav).mockImplementation(()=>new Promise(resolve=>{release=resolve}))
  const {result}=renderHook(useAudioConversion);let pending!:Promise<void>
  act(()=>{pending=result.current.start(new File(['mp3'],'source.mp3'));void result.current.start(new File(['mp3'],'duplicate.mp3'))})
  expect(convertToWav).toHaveBeenCalledOnce();const signal=vi.mocked(convertToWav).mock.calls[0][1]
  act(()=>result.current.reset());expect(signal.aborted).toBe(true)
  await act(async()=>{release(output);await pending})
  expect(result.current.result).toBeNull();expect(result.current.stage).toBe('idle');expect(create).not.toHaveBeenCalled()
 })
 it('aborts an active job when the screen unmounts',async()=>{
  vi.mocked(convertToWav).mockImplementation(()=>new Promise(()=>{}))
  const {result,unmount}=renderHook(useAudioConversion)
  act(()=>{void result.current.start(new File(['mp3'],'source.mp3'))})
  const signal=vi.mocked(convertToWav).mock.calls[0][1];unmount();expect(signal.aborted).toBe(true)
 })
 it('shows failures without fabricating a download URL',async()=>{
  vi.mocked(convertToWav).mockRejectedValue(Error('Codec unavailable'))
  const {result}=renderHook(useAudioConversion);await act(async()=>result.current.start(new File(['bad'],'bad.mp3')))
  expect(result.current.stage).toBe('error');expect(result.current.result).toBeNull();expect(create).not.toHaveBeenCalled()
 })
})
