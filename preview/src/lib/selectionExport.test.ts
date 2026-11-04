import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {renderSelectionExport} from './selectionExport'
import {audioFixture} from '../test/audioFixtures'
const effects={volume:1,fadeIn:0,fadeOut:0,normalize:false}
let worker:ProtocolWorker
class ProtocolWorker {onmessage:((event:{data:unknown})=>void)|null=null;onerror:(()=>void)|null=null;onmessageerror:(()=>void)|null=null;terminate=vi.fn();postMessage=vi.fn();constructor(){worker=this}}
beforeEach(()=>vi.stubGlobal('Worker',ProtocolWorker))
afterEach(()=>vi.unstubAllGlobals())
it('transfers selected copies only and reports real worker stages',async()=>{
 const source=audioFixture([Array<number>(32).fill(.2)],8),stages=vi.fn(),controller=new AbortController()
 const pending=renderSelectionExport(source,1,2,effects,16,controller.signal,stages)
 const [payload,transfer]=worker.postMessage.mock.calls[0]
 expect(payload.channels[0]).toHaveLength(8);expect(payload.channels[0].buffer).not.toBe(source.getChannelData(0).buffer)
 expect(transfer).toEqual([payload.channels[0].buffer]);expect(payload.bitDepth).toBe(16)
 worker.onmessage!({data:{kind:'stage',stage:'processing'}});worker.onmessage!({data:{kind:'stage',stage:'encoding'}})
 worker.onmessage!({data:{kind:'result',bytes:new ArrayBuffer(60)}})
 expect((await pending).size).toBe(60);expect(stages.mock.calls.flat()).toEqual(['processing','encoding']);expect(worker.terminate).toHaveBeenCalledOnce()
 expect(source.getChannelData(0)).toHaveLength(32)
})
it('terminates processing on abort and ignores late messages',async()=>{
 const controller=new AbortController(),stages=vi.fn()
 const pending=renderSelectionExport(audioFixture([Array<number>(8).fill(.2)],8),0,1,effects,16,controller.signal,stages)
 const late=worker.onmessage!;late({data:{kind:'stage',stage:'processing'}});controller.abort()
 await expect(pending).rejects.toMatchObject({name:'AbortError'});expect(worker.terminate).toHaveBeenCalledOnce()
 late({data:{kind:'stage',stage:'encoding'}});late({data:{kind:'result',bytes:new ArrayBuffer(60)}});expect(stages).toHaveBeenCalledOnce()
})
it.each(['render','error','messageerror'])('cleans up and rejects worker %s failures',async kind=>{
 const pending=renderSelectionExport(audioFixture([Array<number>(8).fill(.2)],8),0,1,effects,16,new AbortController().signal,vi.fn())
 if(kind==='render')worker.onmessage!({data:{kind:'error',message:'Invalid studio effects'}})
 else if(kind==='error')worker.onerror!()
 else worker.onmessageerror!()
 await expect(pending).rejects.toThrow();expect(worker.terminate).toHaveBeenCalledOnce()
})
it('does not start an invalid or already-cancelled export',async()=>{
 const controller=new AbortController();controller.abort();const constructor=vi.fn();vi.stubGlobal('Worker',constructor)
 await expect(renderSelectionExport(audioFixture([[0,0]],2),0,1,effects,16,controller.signal,vi.fn())).rejects.toMatchObject({name:'AbortError'})
 await expect(renderSelectionExport(audioFixture([[0,0]],2),0,.2,effects,16,new AbortController().signal,vi.fn())).rejects.toThrow()
 expect(constructor).not.toHaveBeenCalled()
})
