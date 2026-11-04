import {act,cleanup,renderHook,waitFor} from '@testing-library/react'
import {IDBFactory} from 'fake-indexeddb'
import {afterEach,beforeEach,expect,it,vi} from 'vitest'
import {useProjectLibrary} from './useProjectLibrary'
import {ProjectRepository,type StoredProject} from '../lib/projectRepository'
import {neutralStudio} from '../lib/studioEffects'
import {audioFixture} from '../test/audioFixtures'
import type {EditorState} from '../types'
import {encodeSelectionAsWav} from '../lib/audio'
beforeEach(()=>{vi.stubGlobal('indexedDB',new IDBFactory());localStorage.clear();localStorage.setItem('ringify.projects.migrated.v2','true')})
afterEach(()=>{cleanup();vi.unstubAllGlobals()})
it('enforces advanced access in the serialized save queue while retaining old settings and media',async()=>{
 const repo=new ProjectRepository(),effects={volume:1,fadeIn:0,fadeOut:0,normalize:false,studio:{...neutralStudio,mid:3}}
 const record:StoredProject={id:'existing',summary:{id:'existing',name:'Retained',sourceName:'source.wav',duration:1,trimStart:0,trimEnd:1,updatedAt:'2026-11-01T00:00:00Z',status:'draft'},sourceDuration:1,source:{bytes:new Uint8Array([1,2,3]).buffer,type:'audio/wav'},effects}
 await repo.put(record)
 const editor:EditorState={projectID:record.id,projectName:'Retained',asset:{fileName:'source.wav',buffer:audioFixture([Array<number>(8000).fill(.1)],8000),duration:1,isDemo:false,peaks:[]},effects,trimStart:0,trimEnd:1}
 const {result,rerender}=renderHook(({pro})=>useProjectLibrary(vi.fn(),{hasVerifiedPro:pro,language:'tr'}),{initialProps:{pro:false}})
 await waitFor(()=>expect(result.current.loading).toBe(false))
 await act(async()=>result.current.save(editor))
 const altered={...editor,effects:{...effects,studio:{...effects.studio,mid:6}}}
 await act(async()=>{await expect(result.current.save(altered)).rejects.toThrow(/Pro/)})
 expect((await repo.get(record.id))!.effects.studio!.mid).toBe(3)
 await act(async()=>result.current.save({...editor,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}))
 expect((await repo.get(record.id))!.effects.studio).toBeUndefined()
 rerender({pro:true});await act(async()=>result.current.save(altered))
 const restored=(await new ProjectRepository().get(record.id))!
 expect(restored.effects.studio!.mid).toBe(6);expect(new Uint8Array(restored.source!.bytes)).toEqual(new Uint8Array([1,2,3]));expect(await repo.list()).toHaveLength(1)
})
it('enforces PCM24 access at commit, preserves an old PCM24 download and accepts verified Pro output',async()=>{
 const effects={volume:1,fadeIn:0,fadeOut:0,normalize:false},buffer=audioFixture([Array<number>(8000).fill(.1)],8000)
 const bytes=await encodeSelectionAsWav(buffer,0,1,effects,24).arrayBuffer(),repository=new ProjectRepository()
 const record:StoredProject={id:'precision',summary:{id:'precision',name:'Retained24',sourceName:'source.wav',duration:1,trimStart:0,trimEnd:1,updatedAt:'2026-11-01T00:00:00Z',status:'exported'},sourceDuration:1,source:{bytes:new Uint8Array([1,2,3]).buffer,type:'audio/wav'},output:{bytes,type:'audio/wav'},effects}
 await repository.put(record)
 const editor:EditorState={projectID:'precision',projectName:'Retained24',asset:{fileName:'source.wav',buffer,duration:1,peaks:[],isDemo:false},trimStart:0,trimEnd:1,effects}
 const {result,rerender}=renderHook(({pro})=>useProjectLibrary(vi.fn(),{hasVerifiedPro:pro,language:'tr'}),{initialProps:{pro:false}})
 await waitFor(()=>expect(result.current.loading).toBe(false))
 await act(async()=>result.current.save(editor))
 expect((await result.current.get('precision'))!.output!.bytes).toEqual(bytes)
 await act(async()=>{await expect(result.current.save(editor,new Blob([bytes],{type:'audio/wav'}))).rejects.toThrow(/24-bit/)})
 expect((await repository.get('precision'))!.output!.bytes).toEqual(bytes)
 rerender({pro:true});await act(async()=>result.current.save(editor,new Blob([bytes],{type:'audio/wav'})))
 const saved=(await repository.get('precision'))!;expect(new DataView(saved.output!.bytes).getUint16(34,true)).toBe(24)
 expect(new Uint8Array(saved.source!.bytes)).toEqual(new Uint8Array([1,2,3]));expect(await repository.list()).toHaveLength(1)
})
